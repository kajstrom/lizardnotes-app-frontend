import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dropzone/flutter_dropzone.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mime/mime.dart';

import '../../../theme/colour_tokens.dart';
import '../../../theme/text_styles.dart';
import '../providers/attachment_provider.dart';
import '../web/web_attachment_io_stub.dart'
    if (dart.library.js_interop) '../web/web_attachment_io.dart' as webio;

const int _maxFileSize = 25 * 1024 * 1024;
const List<String> _allowedExtensions = ['pdf', 'png', 'jpg', 'md', 'xlsx'];

Future<void> showUploadOverlay({
  required BuildContext context,
  required String noteId,
}) =>
    showDialog<void>(
      context: context,
      builder: (_) => UploadOverlay(noteId: noteId),
    );

class UploadOverlay extends ConsumerStatefulWidget {
  const UploadOverlay({super.key, required this.noteId});

  final String noteId;

  @override
  ConsumerState<UploadOverlay> createState() => _UploadOverlayState();
}

enum _RowStatus { uploading, complete, failed }

class _UploadRow {
  _UploadRow({
    required this.filename,
    required this.mimeType,
    required this.source,
    this.status = _RowStatus.uploading,
    this.error,
  }) : progress = 0.0;

  final String filename;
  final String mimeType;
  final UploadSource source;
  _RowStatus status;
  double progress;
  String? error;

  int get size => source.size;
  // Stream sources are single-shot; retry would drain an already-consumed
  // stream. Bytes and web Blob references can be replayed.
  bool get canRetry =>
      source is BytesSource || source is webio.WebBlobSource;
}

class _UploadOverlayState extends ConsumerState<UploadOverlay> {
  final List<_UploadRow> _rows = [];
  bool _dragOver = false;
  DropzoneViewController? _dropzone;

  bool get _anyUploading =>
      _rows.any((r) => r.status == _RowStatus.uploading);

  // ── File intake ────────────────────────────────────────────────────────

  Future<void> _pickFiles() async {
    if (kIsWeb) {
      // Use a raw <input type="file"> and keep the JS Blob reference. Mobile
      // browsers OOM even with file_picker_web's withReadStream because that
      // path still calls FileReader.readAsArrayBuffer under the hood. Passing
      // the Blob to XHR.send() lets the browser stream it natively.
      const accept =
          '.pdf,.png,.jpg,.md,.xlsx,image/png,image/jpeg';
      final picked = await webio.pickWebFiles(accept: accept);
      for (final f in picked) {
        _addRowFromSource(
          filename: f.name,
          mimeType:
              lookupMimeType(f.name) ??
                  (f.mimeType.isEmpty ? 'application/octet-stream' : f.mimeType),
          source: webio.WebBlobSource(blob: f.blob, size: f.size),
        );
      }
      return;
    }

    // Native (mobile/desktop): file_picker streams from disk.
    final result = await FilePicker.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: _allowedExtensions,
      withReadStream: true,
    );
    if (result == null) return;
    for (final f in result.files) {
      final stream = f.readStream;
      if (stream == null) continue;
      _addRowFromSource(
        filename: f.name,
        mimeType: lookupMimeType(f.name) ?? 'application/octet-stream',
        source: StreamSource(stream: stream, size: f.size),
      );
    }
  }

  Future<void> _handleDrop(DropzoneFileInterface dropped) async {
    if (_dropzone == null) return;
    final name = await _dropzone!.getFilename(dropped);
    final bytes = await _dropzone!.getFileData(dropped);
    final mime = await _dropzone!.getFileMIME(dropped);
    if (!mounted) return;
    setState(() => _dragOver = false);
    _addRowFromSource(
      filename: name,
      mimeType: mime.isEmpty ? 'application/octet-stream' : mime,
      source: BytesSource(bytes),
    );
  }

  void _addRowFromSource({
    required String filename,
    required String mimeType,
    required UploadSource source,
  }) {
    if (source.size > _maxFileSize) {
      setState(() {
        _rows.add(_UploadRow(
          filename: filename,
          mimeType: mimeType,
          source: source,
          status: _RowStatus.failed,
          error: 'exceeds 25 MB limit',
        ));
      });
      return;
    }
    final ext = filename.split('.').last.toLowerCase();
    if (!_allowedExtensions.contains(ext)) {
      setState(() {
        _rows.add(_UploadRow(
          filename: filename,
          mimeType: mimeType,
          source: source,
          status: _RowStatus.failed,
          error: 'unsupported file type',
        ));
      });
      return;
    }

    final row = _UploadRow(
      filename: filename,
      mimeType: mimeType,
      source: source,
    );
    setState(() => _rows.add(row));
    _startUpload(row);
  }

  void _startUpload(_UploadRow row) {
    ref.read(attachmentProvider(widget.noteId).notifier).uploadAttachment(
          filename: row.filename,
          mimeType: row.mimeType,
          source: row.source,
          onProgress: (p) {
            if (!mounted) return;
            setState(() => row.progress = p);
          },
          onComplete: () {
            if (!mounted) return;
            setState(() => row.status = _RowStatus.complete);
          },
          onError: (err) {
            if (!mounted) return;
            setState(() {
              row.status = _RowStatus.failed;
              row.error = err;
            });
          },
        );
  }

  void _retry(_UploadRow row) {
    setState(() {
      row.status = _RowStatus.uploading;
      row.progress = 0;
      row.error = null;
    });
    _startUpload(row);
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: LnColors.lnSurface2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Attach files', style: LnTextStyles.modalTitle()),
              const SizedBox(height: 14),
              _buildDropZone(),
              if (_rows.isNotEmpty) ...[
                const SizedBox(height: 14),
                ..._rows.map(_buildRow),
              ],
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (!_anyUploading)
                    TextButton(
                      key: const Key('upload-overlay-done'),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Done',
                          style: TextStyle(color: LnColors.lnText)),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDropZone() {
    final borderColor =
        _dragOver ? LnColors.lnAccent : LnColors.lnBorder2;
    final bgColor = _dragOver ? LnColors.lnAccentBg : Colors.transparent;
    final titleColor = _dragOver ? LnColors.lnAccent2 : LnColors.lnText;
    final title = _dragOver ? 'Drop to attach' : 'Drag and drop or browse';

    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: CustomPaint(
        painter: _DashedRectPainter(color: borderColor),
        child: Stack(
          children: [
            if (kIsWeb)
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                bottom: 32,
                child: DropzoneView(
                  operation: DragOperation.copy,
                  onCreated: (c) => _dropzone = c,
                  onHover: () {
                    if (!_dragOver) {
                      setState(() => _dragOver = true);
                    }
                  },
                  onLeave: () {
                    if (_dragOver) setState(() => _dragOver = false);
                  },
                  onDropFile: _handleDrop,
                ),
              ),
            IgnorePointer(
              child: Padding(
                padding: const EdgeInsets.only(top: 22),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: LnTextStyles.modalTitle(color: titleColor),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Up to 25 MB each · PDF, PNG, JPG, MD, XLSX',
                        style: LnTextStyles.timestamp(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 4,
              height: 28,
              child: Center(
                child: TextButton(
                  onPressed: _pickFiles,
                  style: TextButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                    minimumSize: const Size(0, 24),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Browse files',
                    style: TextStyle(color: LnColors.lnAccent2, fontSize: 12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(_UploadRow row) {
    final ext = row.filename.split('.').last.toUpperCase();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: LnColors.lnSurface3,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              ext.length > 4 ? ext.substring(0, 4) : ext,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 9,
                fontWeight: FontWeight.w500,
                color: LnColors.lnText2,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.filename,
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w400,
                    color: LnColors.lnText,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                _rowSubLine(row),
              ],
            ),
          ),
          if (row.status == _RowStatus.uploading)
            SizedBox(
              width: 100,
              child: LinearProgressIndicator(
                value: row.progress,
                minHeight: 3,
                backgroundColor: LnColors.lnSurface3,
                valueColor: const AlwaysStoppedAnimation(LnColors.lnAccent),
              ),
            ),
          if (row.status == _RowStatus.complete)
            const Icon(Icons.check_circle,
                size: 16, color: LnColors.lnSuccess),
          if (row.status == _RowStatus.failed && row.canRetry)
            TextButton(
              onPressed: () => _retry(row),
              child: const Text('Retry',
                  style: TextStyle(color: LnColors.lnAccent2, fontSize: 12)),
            ),
        ],
      ),
    );
  }

  Widget _rowSubLine(_UploadRow row) {
    final size = _formatSize(row.size);
    final style = LnTextStyles.timestamp();
    switch (row.status) {
      case _RowStatus.uploading:
        final pct = (row.progress * 100).clamp(0, 100).round();
        return Text('$size · $pct%', style: style);
      case _RowStatus.complete:
        return Text('$size · uploaded',
            style: LnTextStyles.timestamp(color: LnColors.lnSuccess));
      case _RowStatus.failed:
        return Text('failed — ${row.error ?? "unknown error"}',
            style: LnTextStyles.timestamp(color: LnColors.lnDanger));
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class _DashedRectPainter extends CustomPainter {
  _DashedRectPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(8),
    );
    final path = Path()..addRRect(rrect);
    const dash = 6.0;
    const gap = 4.0;
    final out = Path();
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = (distance + dash).clamp(0.0, metric.length);
        out.addPath(metric.extractPath(distance, next), Offset.zero);
        distance = next + gap;
      }
    }
    canvas.drawPath(out, paint);
  }

  @override
  bool shouldRepaint(covariant _DashedRectPainter old) => old.color != color;
}
