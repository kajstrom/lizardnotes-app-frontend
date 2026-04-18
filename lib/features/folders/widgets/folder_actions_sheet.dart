import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/colour_tokens.dart';
import '../../../theme/text_styles.dart';
import '../models/folder.dart';
import '../providers/folder_provider.dart';
import 'delete_confirm_dialog.dart';

/// Shows the folder actions bottom sheet (mobile).
/// Handles Rename and Delete.
Future<void> showFolderActionsSheet({
  required BuildContext context,
  required Folder folder,
  required WidgetRef ref,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: LnColors.lnSurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
    ),
    builder: (_) => _FolderActionsSheetContent(
      folder: folder,
      ref: ref,
      parentContext: context,
    ),
  );
}

class _FolderActionsSheetContent extends StatelessWidget {
  const _FolderActionsSheetContent({
    required this.folder,
    required this.ref,
    required this.parentContext,
  });

  final Folder folder;
  final WidgetRef ref;
  final BuildContext parentContext;

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
          // Folder name header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Text(
              folder.name,
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
              _showRenameDialog(parentContext, folder, ref);
            },
          ),
          Container(height: 1, color: LnColors.lnBorder),
          _SheetItem(
            icon: Icons.delete_outline,
            label: 'Delete',
            isDanger: true,
            onTap: () async {
              Navigator.of(context).pop();
              await showDeleteConfirmDialog(
                  context: parentContext, folder: folder);
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

Future<void> _showRenameDialog(
    BuildContext context, Folder folder, WidgetRef ref) async {
  final controller = TextEditingController(text: folder.name);
  final confirmed = await showDialog<bool>(
    context: context,
    barrierColor: const Color(0x80000000),
    builder: (dialogContext) => AlertDialog(
      backgroundColor: LnColors.lnSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      title: Text('Rename folder',
          style: LnTextStyles.modalTitle()),
      content: TextField(
        controller: controller,
        autofocus: true,
        style: LnTextStyles.sidebarFolder(color: LnColors.lnText),
        cursorColor: LnColors.lnAccent,
        decoration: InputDecoration(
          filled: true,
          fillColor: LnColors.lnSurface2,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: LnColors.lnBorder2),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: LnColors.lnAccent),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
        onSubmitted: (_) => Navigator.of(dialogContext).pop(true),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text('Cancel',
              style: LnTextStyles.primaryButton(color: LnColors.lnText2)),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text('Rename',
              style: LnTextStyles.primaryButton(color: LnColors.lnAccent)),
        ),
      ],
    ),
  );

  if (confirmed == true) {
    final newName = controller.text.trim();
    if (newName.isNotEmpty && newName != folder.name) {
      ref.read(folderProvider.notifier).renameFolder(folder.folderId, newName);
    }
  }
  controller.dispose();
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
            Icon(icon,
                size: 18,
                color: isDanger ? LnColors.lnDanger : LnColors.lnText2),
            const SizedBox(width: 14),
            Text(label, style: LnTextStyles.sidebarFolder(color: color)),
          ],
        ),
      ),
    );
  }
}
