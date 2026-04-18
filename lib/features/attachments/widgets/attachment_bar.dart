import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
