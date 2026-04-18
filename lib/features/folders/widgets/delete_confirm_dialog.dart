import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/colour_tokens.dart';
import '../../../theme/text_styles.dart';
import '../models/folder.dart';
import '../providers/folder_provider.dart';

/// Opens the Delete confirmation dialog for [folder].
/// Returns true if deletion was confirmed.
Future<bool> showDeleteConfirmDialog({
  required BuildContext context,
  required Folder folder,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierColor: const Color(0x80000000),
    builder: (_) => DeleteConfirmDialog(folder: folder),
  );
  return result ?? false;
}

class DeleteConfirmDialog extends ConsumerWidget {
  const DeleteConfirmDialog({super.key, required this.folder});

  final Folder folder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(folderProvider.notifier);
    final descendantIds = notifier.allDescendantIds(folder.folderId);
    final subfoldersCount = descendantIds.length;

    // Notes count: not yet implemented — show 0 until notes provider exists.
    const notesCount = 0;

    void confirm() {
      notifier.deleteFolder(folder.folderId);
      Navigator.of(context).pop(true);
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Material(
          color: LnColors.lnSurface,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text(
                  'Delete \u201c${folder.name}\u201d?',
                  style: LnTextStyles.modalTitle(),
                ),
                const SizedBox(height: 14),
                // Warning box
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: LnColors.lnDangerBg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: LnColors.lnDanger),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        size: 16,
                        color: LnColors.lnDanger,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'This folder contains $notesCount '
                          '${notesCount == 1 ? 'note' : 'notes'} and '
                          '$subfoldersCount '
                          '${subfoldersCount == 1 ? 'subfolder' : 'subfolders'}. '
                          'All will be permanently deleted.',
                          style: LnTextStyles.authSubtitle(
                            color: LnColors.lnText,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // Footer
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _GhostButton(
                      label: 'Cancel',
                      onTap: () => Navigator.of(context).pop(false),
                    ),
                    const SizedBox(width: 8),
                    _DangerButton(
                      label: 'Delete all',
                      onTap: confirm,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Footer buttons
// ---------------------------------------------------------------------------

class _GhostButton extends StatefulWidget {
  const _GhostButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  State<_GhostButton> createState() => _GhostButtonState();
}

class _GhostButtonState extends State<_GhostButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: _hovered ? LnColors.lnSurface3 : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: LnColors.lnBorder2),
          ),
          child: Text(
            widget.label,
            style: LnTextStyles.primaryButton(color: LnColors.lnText2),
          ),
        ),
      ),
    );
  }
}

class _DangerButton extends StatefulWidget {
  const _DangerButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  State<_DangerButton> createState() => _DangerButtonState();
}

class _DangerButtonState extends State<_DangerButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: _hovered
                ? LnColors.lnDanger
                : LnColors.lnDangerBg,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: LnColors.lnDanger),
          ),
          child: Text(
            widget.label,
            style: LnTextStyles.primaryButton(
              color: _hovered ? LnColors.lnText : LnColors.lnDanger,
            ),
          ),
        ),
      ),
    );
  }
}
