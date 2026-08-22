import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart' show XFile;

import '../../../theme/colour_tokens.dart';
import '../../../theme/text_styles.dart';
import '../providers/attachment_provider.dart';
import 'attachment_chip.dart';
import 'upload_overlay.dart';

/// Pinned bottom bar above the editor (desktop) / format toolbar (mobile).
///
/// Lists attachments for the current note and exposes a "+ attach file"
/// trigger that opens `UploadOverlay`.
class AttachmentBar extends ConsumerWidget {
  const AttachmentBar({super.key, required this.noteId});

  final String noteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(attachmentProvider(noteId));

    return Container(
      constraints: const BoxConstraints(minHeight: 50),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      decoration: const BoxDecoration(
        color: LnColors.lnSurface,
        border: Border(top: BorderSide(color: LnColors.lnBorder, width: 1)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            Text('ATTACHMENTS', style: LnTextStyles.sectionLabel()),
            const SizedBox(width: 12),
            for (final item in state.items) ...[
              AttachmentChip(noteId: noteId, item: item),
              const SizedBox(width: 8),
            ],
            _AttachTrigger(noteId: noteId),
            if (!kIsWeb) ...[
              const SizedBox(width: 8),
              _TakePhotoTrigger(noteId: noteId),
            ],
          ],
        ),
      ),
    );
  }
}

class _AttachTrigger extends StatelessWidget {
  const _AttachTrigger({required this.noteId});

  final String noteId;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => showUploadOverlay(context: context, noteId: noteId),
      borderRadius: BorderRadius.circular(5),
      child: DottedBorder(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.add, size: 12, color: LnColors.lnText2),
              const SizedBox(width: 4),
              Text(
                'attach file',
                style: LnTextStyles.timestamp(color: LnColors.lnText2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TakePhotoTrigger extends ConsumerStatefulWidget {
  const _TakePhotoTrigger({required this.noteId});

  final String noteId;

  @override
  ConsumerState<_TakePhotoTrigger> createState() => _TakePhotoTriggerState();
}

class _TakePhotoTriggerState extends ConsumerState<_TakePhotoTrigger> {
  bool _busy = false;

  Future<void> _takePhoto() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final XFile? photo = await ref.read(cameraPickerProvider)();
      if (photo == null) return;

      final bytes = await photo.readAsBytes();
      final filename = 'photo_${DateTime.now().millisecondsSinceEpoch}.jpg';

      ref.read(attachmentProvider(widget.noteId).notifier).uploadAttachment(
            filename: filename,
            mimeType: 'image/jpeg',
            source: BytesSource(bytes),
            onError: (err) => _showError('Upload failed: $err'),
          );
    } on PlatformException catch (e) {
      _showError(e.code == 'camera_access_denied'
          ? 'Camera permission denied. Enable it in system settings to take photos.'
          : 'Could not open camera: ${e.message ?? e.code}');
    } catch (e) {
      _showError('Could not take photo: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _busy ? null : _takePhoto,
      borderRadius: BorderRadius.circular(5),
      child: DottedBorder(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_busy)
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: LnColors.lnText2,
                  ),
                )
              else
                const Icon(Icons.camera_alt_outlined,
                    size: 12, color: LnColors.lnText2),
              const SizedBox(width: 4),
              Text(
                'take photo',
                style: LnTextStyles.timestamp(color: LnColors.lnText2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Simple dashed-border container — avoids pulling in `dotted_border` pkg.
class DottedBorder extends StatelessWidget {
  const DottedBorder({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedRectPainter(
        color: LnColors.lnBorder2,
        radius: 5,
        strokeWidth: 1,
        dashLength: 3,
        gapLength: 3,
      ),
      child: child,
    );
  }
}

class _DashedRectPainter extends CustomPainter {
  _DashedRectPainter({
    required this.color,
    required this.radius,
    required this.strokeWidth,
    required this.dashLength,
    required this.gapLength,
  });

  final Color color;
  final double radius;
  final double strokeWidth;
  final double dashLength;
  final double gapLength;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    final dashed = _dashPath(path, dashLength, gapLength);
    canvas.drawPath(dashed, paint);
  }

  Path _dashPath(Path source, double dash, double gap) {
    final out = Path();
    for (final metric in source.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + dash;
        out.addPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          Offset.zero,
        );
        distance = next + gap;
      }
    }
    return out;
  }

  @override
  bool shouldRepaint(covariant _DashedRectPainter old) =>
      old.color != color ||
      old.radius != radius ||
      old.strokeWidth != strokeWidth ||
      old.dashLength != dashLength ||
      old.gapLength != gapLength;
}
