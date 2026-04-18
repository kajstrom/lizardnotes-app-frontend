import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/colour_tokens.dart';
import '../../../theme/text_styles.dart';
import '../../folders/models/folder.dart';
import '../../folders/providers/folder_provider.dart';
import '../models/note.dart';
import '../providers/note_provider.dart';

/// Opens the Move dialog for [note]. Returns true if the move was confirmed.
Future<bool> showNoteMoveDialog({
  required BuildContext context,
  required Note note,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierColor: const Color(0x80000000),
    builder: (_) => NoteMoveDialog(note: note),
  );
  return result ?? false;
}

class NoteMoveDialog extends ConsumerStatefulWidget {
  const NoteMoveDialog({super.key, required this.note});

  final Note note;

  @override
  ConsumerState<NoteMoveDialog> createState() => _NoteMoveDialogState();
}

class _NoteMoveDialogState extends ConsumerState<NoteMoveDialog> {
  String? _selectedDestination;
  bool _destinationChosen = false;

  bool _isDisabled(Folder candidate) {
    // Only disable the note's current parent folder.
    return candidate.folderId == widget.note.folderId;
  }

  void _selectDestination(String? folderId) {
    setState(() {
      _selectedDestination = folderId;
      _destinationChosen = true;
    });
  }

  void _confirm() {
    if (_selectedDestination != null) {
      ref
          .read(noteProvider.notifier)
          .moveNote(widget.note.noteId, _selectedDestination!);
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final folderState = ref.watch(folderProvider);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Material(
          color: LnColors.lnSurface,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Move note', style: LnTextStyles.modalTitle()),
                const SizedBox(height: 6),
                Text(
                  'Choose a new location for \u201c${widget.note.title.isEmpty ? 'Untitled' : widget.note.title}\u201d',
                  style: LnTextStyles.authSubtitle(),
                ),
                const SizedBox(height: 16),
                Container(
                  constraints: const BoxConstraints(maxHeight: 280),
                  decoration: BoxDecoration(
                    color: LnColors.lnBg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: LnColors.lnBorder2),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: folderState.folders.map(
                          (f) => _DestinationRow(
                            label: f.name,
                            isSelected: _destinationChosen &&
                                _selectedDestination == f.folderId,
                            isDisabled: _isDisabled(f),
                            depth: _depthOf(f, folderState.folders),
                            onTap: () => _selectDestination(f.folderId),
                          ),
                        ).toList(),
                      ),
                    ),
                  ),
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
                    _PrimaryButton(
                      label: 'Move here',
                      enabled: _destinationChosen,
                      onTap: _confirm,
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
// Helpers
// ---------------------------------------------------------------------------

int _depthOf(Folder folder, List<Folder> allFolders) {
  int depth = 0;
  String? parentId = folder.parentFolderId;
  while (parentId != null) {
    depth++;
    final parent = allFolders.cast<Folder?>().firstWhere(
          (f) => f?.folderId == parentId,
          orElse: () => null,
        );
    parentId = parent?.parentFolderId;
  }
  return depth;
}

// ---------------------------------------------------------------------------
// Destination row
// ---------------------------------------------------------------------------

class _DestinationRow extends StatefulWidget {
  const _DestinationRow({
    required this.label,
    required this.isSelected,
    required this.isDisabled,
    required this.depth,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final bool isDisabled;
  final int depth;
  final VoidCallback onTap;

  @override
  State<_DestinationRow> createState() => _DestinationRowState();
}

class _DestinationRowState extends State<_DestinationRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    Color bg;
    if (widget.isSelected) {
      bg = LnColors.lnAccentBg;
    } else if (_hovered && !widget.isDisabled) {
      bg = LnColors.lnSurface3;
    } else {
      bg = Colors.transparent;
    }

    return Opacity(
      opacity: widget.isDisabled ? 0.55 : 1.0,
      child: MouseRegion(
        cursor: widget.isDisabled
            ? SystemMouseCursors.forbidden
            : SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.isDisabled ? null : widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 80),
            padding: EdgeInsets.only(
              left: 8 + widget.depth * 14.0,
              right: 8,
              top: 6,
              bottom: 6,
            ),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.folder_outlined,
                  size: 14,
                  color: widget.isSelected
                      ? LnColors.lnAccent2
                      : LnColors.lnText3,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    widget.label,
                    style: LnTextStyles.sidebarFolder(
                      color: widget.isSelected
                          ? LnColors.lnAccent2
                          : LnColors.lnText,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
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

class _PrimaryButton extends StatefulWidget {
  const _PrimaryButton({
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  State<_PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<_PrimaryButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.enabled
          ? SystemMouseCursors.click
          : SystemMouseCursors.forbidden,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.enabled ? widget.onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: widget.enabled
                ? (_hovered ? LnColors.lnAccent2 : LnColors.lnAccent)
                : LnColors.lnSurface3,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            widget.label,
            style: LnTextStyles.primaryButton(
              color: widget.enabled ? LnColors.lnText : LnColors.lnText3,
            ),
          ),
        ),
      ),
    );
  }
}
