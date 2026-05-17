import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../theme/colour_tokens.dart';
import '../providers/attachment_provider.dart';

/// One chip per attachment, rendered inside `AttachmentBar`.
///
/// Visual variant is driven by `item.status`.
class AttachmentChip extends ConsumerWidget {
  const AttachmentChip({
    super.key,
    required this.noteId,
    required this.item,
  });

  final String noteId;
  final AttachmentItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    switch (item.status) {
      case UploadStatus.uploading:
        return _uploadingChip();
      case UploadStatus.complete:
        return _completeChip();
      case UploadStatus.failed:
      case UploadStatus.idle:
        return _idleChip(context, ref);
    }
  }

  // ── Idle ────────────────────────────────────────────────────────────────

  Widget _idleChip(BuildContext context, WidgetRef ref) {
    return _ChipMenuButton(
      onSelected: (action) => _handleAction(context, ref, action),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: LnColors.lnSurface2,
          border: Border.all(color: LnColors.lnBorder2, width: 1),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.attach_file, size: 12, color: LnColors.lnText2),
            const SizedBox(width: 6),
            Text(item.attachment.filename, style: _monoText(LnColors.lnText2)),
          ],
        ),
      ),
    );
  }

  Future<void> _handleAction(
      BuildContext context, WidgetRef ref, _ChipAction action) async {
    final notifier = ref.read(attachmentProvider(noteId).notifier);
    switch (action) {
      case _ChipAction.open:
        await notifier.openAttachment(item.attachment.attachmentId);
        break;
      case _ChipAction.download:
        await notifier.downloadAttachment(item.attachment.attachmentId);
        break;
      case _ChipAction.copy:
        await notifier.copyLink(item.attachment.attachmentId);
        break;
      case _ChipAction.remove:
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (_) => _ConfirmRemoveDialog(filename: item.attachment.filename),
        );
        if (confirmed == true) {
          await notifier.deleteAttachment(item.attachment.attachmentId);
        }
        break;
    }
  }

  // ── Uploading ───────────────────────────────────────────────────────────

  Widget _uploadingChip() {
    final pct = (item.progress * 100).clamp(0, 100).round();
    return ClipRRect(
      borderRadius: BorderRadius.circular(5),
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: LnColors.lnSurface2,
              border: Border.all(color: LnColors.lnAccent, width: 1),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.attach_file, size: 12, color: LnColors.lnAccent2),
                const SizedBox(width: 6),
                Text(
                  '${item.attachment.filename} $pct%',
                  style: _monoText(LnColors.lnAccent2),
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: item.progress.clamp(0.0, 1.0),
              child: Container(height: 2, color: LnColors.lnAccent),
            ),
          ),
        ],
      ),
    );
  }

  // ── Complete ────────────────────────────────────────────────────────────

  Widget _completeChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: LnColors.lnSurface2,
        // 0.55-opacity success — not a token.
        border: Border.all(color: const Color(0x8C4A9E6A), width: 1),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check, size: 12, color: LnColors.lnSuccess),
          const SizedBox(width: 6),
          Text(item.attachment.filename, style: _monoText(LnColors.lnSuccess)),
        ],
      ),
    );
  }

  TextStyle _monoText(Color color) => GoogleFonts.jetBrainsMono(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: color,
      );
}

// ---------------------------------------------------------------------------
// Popup menu
// ---------------------------------------------------------------------------

enum _ChipAction { open, download, copy, remove }

class _ChipMenuButton extends StatelessWidget {
  const _ChipMenuButton({required this.child, required this.onSelected});

  final Widget child;
  final ValueChanged<_ChipAction> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_ChipAction>(
      tooltip: '',
      color: LnColors.lnSurface2,
      position: PopupMenuPosition.under,
      onSelected: onSelected,
      itemBuilder: (_) => const [
        PopupMenuItem(value: _ChipAction.open, child: Text('Open')),
        PopupMenuItem(value: _ChipAction.download, child: Text('Download')),
        PopupMenuItem(value: _ChipAction.copy, child: Text('Copy link')),
        PopupMenuItem(value: _ChipAction.remove, child: Text('Remove')),
      ],
      child: child,
    );
  }
}

// ---------------------------------------------------------------------------
// Confirm-remove dialog
// ---------------------------------------------------------------------------

class _ConfirmRemoveDialog extends StatelessWidget {
  const _ConfirmRemoveDialog({required this.filename});

  final String filename;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: LnColors.lnSurface2,
      title: const Text('Remove attachment?'),
      content: Text('"$filename" will be permanently deleted.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text(
            'Remove',
            style: TextStyle(color: LnColors.lnDanger),
          ),
        ),
      ],
    );
  }
}
