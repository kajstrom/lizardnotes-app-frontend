import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../api/api_client.dart';
import '../models/attachment.dart';

// ---------------------------------------------------------------------------
// Injectable seams (overridden in tests)
// ---------------------------------------------------------------------------

typedef S3Uploader = Future<void> Function({
  required String url,
  required Uint8List bytes,
  required String contentType,
  void Function(int sent, int total)? onProgress,
});

Future<void> _defaultS3Upload({
  required String url,
  required Uint8List bytes,
  required String contentType,
  void Function(int sent, int total)? onProgress,
}) async {
  final dio = Dio();
  await dio.put<void>(
    url,
    data: Stream.fromIterable([bytes]),
    options: Options(
      headers: {
        Headers.contentTypeHeader: contentType,
        Headers.contentLengthHeader: bytes.length,
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
    required Uint8List bytes,
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
        size: bytes.length,
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
        size: bytes.length,
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
        bytes: bytes,
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

  Future<void> downloadAttachment(String attachmentId) async {
    final url = await _api.getAttachmentDownloadUrl(
      noteId: _noteId,
      attachmentId: attachmentId,
    );
    await _opener(url);
  }

  Future<void> copyLink(String attachmentId) async {
    final url = await _api.getAttachmentDownloadUrl(
      noteId: _noteId,
      attachmentId: attachmentId,
    );
    await _clipboard(url);
  }

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
