import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/colour_tokens.dart';
import '../../../theme/text_styles.dart';
import '../models/note.dart';
import 'note_delete_confirm_dialog.dart';
import 'note_move_dialog.dart';

/// Shows the note actions bottom sheet (mobile).
/// Handles Rename, Move, Copy link, and Delete.
Future<void> showNoteActionsSheet({
  required BuildContext context,
  required Note note,
  required WidgetRef ref,
  VoidCallback? onRename,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: LnColors.lnSurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
    ),
    builder: (_) => _NoteActionsSheetContent(
      note: note,
      ref: ref,
      onRename: onRename,
      parentContext: context,
    ),
  );
}

class _NoteActionsSheetContent extends StatelessWidget {
  const _NoteActionsSheetContent({
    required this.note,
    required this.ref,
    required this.parentContext,
    this.onRename,
  });

  final Note note;
  final WidgetRef ref;
  final BuildContext parentContext;
  final VoidCallback? onRename;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle bar
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: LnColors.lnBorder3,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Note title header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Text(
              note.title.isEmpty ? 'Untitled' : note.title,
              style: LnTextStyles.noteCardTitle(color: LnColors.lnText2),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(height: 1, color: LnColors.lnBorder),
          _SheetItem(
            icon: Icons.edit_outlined,
            label: 'Rename',
            onTap: () {
              Navigator.of(context).pop();
              onRename?.call();
            },
          ),
          _SheetItem(
            icon: Icons.drive_file_move_outlined,
            label: 'Move to folder',
            onTap: () async {
              Navigator.of(context).pop();
              await showNoteMoveDialog(context: parentContext, note: note);
            },
          ),
          _SheetItem(
            icon: Icons.link,
            label: 'Copy link',
            onTap: () async {
              Navigator.of(context).pop();
              await Clipboard.setData(
                ClipboardData(text: '/app/notes/${note.noteId}'),
              );
            },
          ),
          Container(height: 1, color: LnColors.lnBorder),
          _SheetItem(
            icon: Icons.delete_outline,
            label: 'Delete',
            isDanger: true,
            onTap: () async {
              Navigator.of(context).pop();
              await showNoteDeleteConfirmDialog(
                  context: parentContext, note: note);
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _SheetItem extends StatelessWidget {
  const _SheetItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDanger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDanger;

  @override
  Widget build(BuildContext context) {
    final color = isDanger ? LnColors.lnDanger : LnColors.lnText;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 18, color: isDanger ? LnColors.lnDanger : LnColors.lnText2),
            const SizedBox(width: 14),
            Text(label, style: LnTextStyles.sidebarFolder(color: color)),
          ],
        ),
      ),
    );
  }
}
