import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/colour_tokens.dart';
import '../../../theme/text_styles.dart';
import '../models/note.dart';
import '../providers/note_provider.dart';

/// Opens the Delete confirmation dialog for [note].
/// Returns true if deletion was confirmed.
Future<bool> showNoteDeleteConfirmDialog({
  required BuildContext context,
  required Note note,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierColor: const Color(0x80000000),
    builder: (_) => NoteDeleteConfirmDialog(note: note),
  );
  return result ?? false;
}

class NoteDeleteConfirmDialog extends ConsumerWidget {
  const NoteDeleteConfirmDialog({super.key, required this.note});

  final Note note;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void confirm() {
      ref.read(noteProvider.notifier).deleteNote(note.noteId);
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
                Text(
                  'Delete \u201c${note.title.isEmpty ? 'Untitled' : note.title}\u201d?',
                  style: LnTextStyles.modalTitle(),
                ),
                const SizedBox(height: 14),
                Text(
                  'This note will be permanently deleted. '
                  'This action cannot be undone.',
                  style: LnTextStyles.authSubtitle(),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _GhostButton(
                      label: 'Cancel',
                      onTap: () => Navigator.of(context).pop(false),
                    ),
                    const SizedBox(width: 8),
                    _DangerButton(
                      label: 'Delete note',
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
            color: _hovered ? LnColors.lnDanger : LnColors.lnDangerBg,
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
