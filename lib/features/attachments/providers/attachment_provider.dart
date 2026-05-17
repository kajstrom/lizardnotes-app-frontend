import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../api/api_client.dart';
import '../models/attachment.dart';
import '../../search/providers/attachment_registry_provider.dart';
import '../web/web_attachment_io_stub.dart'
    if (dart.library.js_interop) '../web/web_attachment_io.dart' as webio;

// ---------------------------------------------------------------------------
// Upload source — abstracts bytes-in-memory vs streaming-from-blob.
//
// On mobile browsers, reading a 5–25 MB camera photo into a Uint8List via
// FileReader.readAsArrayBuffer can OOM the tab. StreamSource lets the file
// stream straight to S3 in chunks without ever materializing the whole file.
// ---------------------------------------------------------------------------

// Not `sealed` — WebBlobSource lives in a conditionally-imported file so that
// `dart:js_interop` doesn't leak into native/test compilation.
abstract class UploadSource {
  const UploadSource();
  int get size;
  Stream<List<int>> openRead();
}

class BytesSource extends UploadSource {
  const BytesSource(this.bytes);
  final Uint8List bytes;
  @override
  int get size => bytes.length;
  @override
  Stream<List<int>> openRead() => Stream.value(bytes);
}

class StreamSource extends UploadSource {
  const StreamSource({required Stream<List<int>> stream, required this.size})
      : _stream = stream;
  final Stream<List<int>> _stream;
  @override
  final int size;
  @override
  Stream<List<int>> openRead() => _stream;
}

// ---------------------------------------------------------------------------
// Injectable seams (overridden in tests)
// ---------------------------------------------------------------------------

typedef S3Uploader = Future<void> Function({
  required String url,
  required UploadSource source,
  required String contentType,
  void Function(int sent, int total)? onProgress,
});

Future<void> _defaultS3Upload({
  required String url,
  required UploadSource source,
  required String contentType,
  void Function(int sent, int total)? onProgress,
}) async {
  // On web, route a WebBlobSource through XHR so the browser streams the Blob
  // directly to S3 — never copying its bytes into the JS/Dart heap. Other
  // sources (and all native platforms) fall through to Dio.
  final handled = await webio.tryUploadWebBlob(
    source: source,
    url: url,
    contentType: contentType,
    onProgress: onProgress,
  );
  if (handled) return;

  final dio = Dio();
  await dio.put<void>(
    url,
    data: source.openRead(),
    options: Options(
      headers: {
        Headers.contentTypeHeader: contentType,
        Headers.contentLengthHeader: source.size,
      },
    ),
    onSendProgress: onProgress,
  );
}

final s3UploaderProvider = Provider<S3Uploader>((_) => _defaultS3Upload);

typedef UrlOpener = Future<bool> Function(String url);

Future<bool> _defaultUrlOpener(String url) =>
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

final urlOpenerProvider = Provider<UrlOpener>((_) => _defaultUrlOpener);

typedef TabOpener = Future<void> Function(String url);

Future<void> _defaultTabOpener(String url) => webio.openUrlInNewTab(url);

final tabOpenerProvider = Provider<TabOpener>((_) => _defaultTabOpener);

typedef ClipboardWriter = Future<void> Function(String text);

Future<void> _defaultClipboardWriter(String text) =>
    Clipboard.setData(ClipboardData(text: text));

final clipboardWriterProvider =
    Provider<ClipboardWriter>((_) => _defaultClipboardWriter);

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

enum UploadStatus { idle, uploading, complete, failed }

class AttachmentItem {
  const AttachmentItem({
    required this.attachment,
    this.status = UploadStatus.idle,
    this.progress = 0.0,
    this.error,
  });

  final Attachment attachment;
  final UploadStatus status;
  final double progress;
  final String? error;

  AttachmentItem copyWith({
    Attachment? attachment,
    UploadStatus? status,
    double? progress,
    String? error,
    bool clearError = false,
  }) =>
      AttachmentItem(
        attachment: attachment ?? this.attachment,
        status: status ?? this.status,
        progress: progress ?? this.progress,
        error: clearError ? null : (error ?? this.error),
      );
}

class AttachmentState {
  const AttachmentState({
    this.items = const [],
    this.loading = false,
    this.errorMessage,
  });

  final List<AttachmentItem> items;
  final bool loading;
  final String? errorMessage;

  AttachmentState copyWith({
    List<AttachmentItem>? items,
    bool? loading,
    String? errorMessage,
    bool clearError = false,
  }) =>
      AttachmentState(
        items: items ?? this.items,
        loading: loading ?? this.loading,
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      );
}

// ---------------------------------------------------------------------------
// Provider (family keyed by noteId)
// ---------------------------------------------------------------------------

final attachmentProvider = NotifierProvider.family<
    AttachmentNotifier, AttachmentState, String>(AttachmentNotifier.new);

class AttachmentNotifier extends Notifier<AttachmentState> {
  AttachmentNotifier(this._noteId);

  final String _noteId;

  ApiClient get _api => ref.read(apiClientProvider);
  S3Uploader get _uploader => ref.read(s3UploaderProvider);
  UrlOpener get _opener => ref.read(urlOpenerProvider);
  TabOpener get _tabOpener => ref.read(tabOpenerProvider);
  ClipboardWriter get _clipboard => ref.read(clipboardWriterProvider);

  @override
  AttachmentState build() => const AttachmentState();

  Future<void> loadAttachments() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final list = await _api.getAttachments(_noteId);
      state = state.copyWith(
        loading: false,
        items: list.map((a) => AttachmentItem(attachment: a)).toList(),
      );
      ref.read(attachmentRegistryProvider.notifier).register(_noteId, list);
    } catch (e) {
      state = state.copyWith(loading: false, errorMessage: e.toString());
    }
  }

  /// Creates the backend record, uploads bytes to S3, tracks progress and
  /// transitions status → complete (which auto-reverts to idle after 3s)
  /// or → failed on error.
  Future<void> uploadAttachment({
    required String filename,
    required String mimeType,
    required UploadSource source,
    void Function(double progress)? onProgress,
    void Function()? onComplete,
    void Function(String error)? onError,
  }) async {
    late Attachment meta;
    late String uploadUrl;
    try {
      final result = await _api.createAttachment(
        noteId: _noteId,
        filename: filename,
        mimeType: mimeType,
        size: source.size,
      );
      meta = result.attachment;
      uploadUrl = result.uploadUrl;
    } catch (e) {
      // Surface as a synthetic failed item so the overlay can show the error.
      final synthetic = Attachment(
        attachmentId: 'local_${DateTime.now().microsecondsSinceEpoch}',
        noteId: _noteId,
        filename: filename,
        mimeType: mimeType,
        size: source.size,
        createdAt: DateTime.now(),
      );
      state = state.copyWith(
        items: [
          ...state.items,
          AttachmentItem(
            attachment: synthetic,
            status: UploadStatus.failed,
            error: e.toString(),
          ),
        ],
      );
      onError?.call(e.toString());
      return;
    }

    // Insert uploading row.
    state = state.copyWith(items: [
      ...state.items,
      AttachmentItem(
        attachment: meta,
        status: UploadStatus.uploading,
      ),
    ]);

    try {
      await _uploader(
        url: uploadUrl,
        source: source,
        contentType: mimeType,
        onProgress: (sent, total) {
          if (total <= 0) return;
          final pct = sent / total;
          _updateItem(meta.attachmentId, (it) => it.copyWith(progress: pct));
          onProgress?.call(pct);
        },
      );
      _updateItem(meta.attachmentId, (it) => it.copyWith(
            status: UploadStatus.complete,
            progress: 1.0,
          ));
      onComplete?.call();
      // Schedule flip back to idle after 3s.
      Timer(const Duration(seconds: 3), () {
        _updateItem(meta.attachmentId, (it) {
          if (it.status != UploadStatus.complete) return it;
          return it.copyWith(status: UploadStatus.idle, clearError: true);
        });
      });
    } catch (e) {
      _updateItem(meta.attachmentId, (it) => it.copyWith(
            status: UploadStatus.failed,
            error: e.toString(),
          ));
      onError?.call(e.toString());
    }
  }

  Future<String> _resolveDownloadUrl(String attachmentId) =>
      _api.getAttachmentDownloadUrl(noteId: _noteId, attachmentId: attachmentId);

  Future<void> downloadAttachment(String attachmentId) async =>
      _opener(await _resolveDownloadUrl(attachmentId));

  Future<void> openAttachment(String attachmentId) async =>
      _tabOpener(await _resolveDownloadUrl(attachmentId));

  Future<void> copyLink(String attachmentId) async =>
      _clipboard(await _resolveDownloadUrl(attachmentId));

  Future<void> deleteAttachment(String attachmentId) async {
    final previous = List<AttachmentItem>.unmodifiable(state.items);
    state = state.copyWith(
      items: state.items
          .where((i) => i.attachment.attachmentId != attachmentId)
          .toList(),
    );
    try {
      await _api.deleteAttachment(
        noteId: _noteId,
        attachmentId: attachmentId,
      );
    } catch (e) {
      state = state.copyWith(
        items: List<AttachmentItem>.from(previous),
        errorMessage: e.toString(),
      );
    }
  }

  void _updateItem(
    String attachmentId,
    AttachmentItem Function(AttachmentItem) update,
  ) {
    state = state.copyWith(
      items: state.items
          .map((i) => i.attachment.attachmentId == attachmentId
              ? update(i)
              : i)
          .toList(),
    );
  }
}
