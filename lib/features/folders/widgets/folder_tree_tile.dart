import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../router/app_router.dart';
import '../../../theme/colour_tokens.dart';
import '../../../theme/text_styles.dart';
import '../models/folder.dart';
import '../providers/folder_provider.dart';
import '../../notes/providers/note_provider.dart';
import 'delete_confirm_dialog.dart';
import 'folder_context_menu.dart';
import 'move_dialog.dart';

class FolderTreeTile extends ConsumerStatefulWidget {
  const FolderTreeTile({
    super.key,
    required this.folder,
    this.depth = 0,
  });

  final Folder folder;
  final int depth;

  @override
  ConsumerState<FolderTreeTile> createState() => _FolderTreeTileState();
}

class _FolderTreeTileState extends ConsumerState<FolderTreeTile> {
  bool _isExpanded = false;
  bool _isHovered = false;
  bool _isRenaming = false;

  late final TextEditingController _renameController;
  late final FocusNode _renameFocus;

  @override
  void initState() {
    super.initState();
    _renameController =
        TextEditingController(text: widget.folder.name);
    _renameFocus = FocusNode();
    _renameFocus.addListener(_onRenameFocusChange);
  }

  @override
  void dispose() {
    _renameController.dispose();
    _renameFocus
      ..removeListener(_onRenameFocusChange)
      ..dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Rename helpers
  // ---------------------------------------------------------------------------

  void _startRename() {
    _renameController.text = widget.folder.name;
    setState(() => _isRenaming = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _renameFocus.requestFocus();
      _renameController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _renameController.text.length,
      );
    });
  }

  void _commitRename() {
    if (!_isRenaming) return;
    final newName = _renameController.text.trim();
    setState(() => _isRenaming = false);
    if (newName.isNotEmpty && newName != widget.folder.name) {
      ref
          .read(folderProvider.notifier)
          .renameFolder(widget.folder.folderId, newName);
    }
  }

  void _cancelRename() {
    if (!_isRenaming) return;
    setState(() => _isRenaming = false);
  }

  void _onRenameFocusChange() {
    if (!_renameFocus.hasFocus) _commitRename();
  }

  // ---------------------------------------------------------------------------
  // Context menu
  // ---------------------------------------------------------------------------

  Future<void> _showContextMenu(Offset globalPosition) async {
    final action = await showFolderContextMenu(
      context: context,
      globalPosition: globalPosition,
    );
    if (!mounted) return;

    switch (action) {
      case FolderMenuAction.rename:
        _startRename();
      case FolderMenuAction.newSubfolder:
        await ref
            .read(folderProvider.notifier)
            .createFolder('New Folder', parentFolderId: widget.folder.folderId);
      case FolderMenuAction.newNote:
        await ref
            .read(noteProvider.notifier)
            .createNote(widget.folder.folderId, 'Untitled');
      case FolderMenuAction.moveTo:
        await showMoveDialog(context: context, folder: widget.folder);
      case FolderMenuAction.delete:
        await showDeleteConfirmDialog(
            context: context, folder: widget.folder);
      case null:
        break;
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final selectedId = ref.watch(selectedFolderIdProvider);
    final isActive = selectedId == widget.folder.folderId;
    final children = ref
        .watch(folderProvider.notifier)
        .childrenOf(widget.folder.folderId);

    final bgColor = isActive
        ? LnColors.lnAccentBg
        : (_isHovered ? LnColors.lnSurface3 : Colors.transparent);
    final textColor =
        isActive ? LnColors.lnAccent2 : LnColors.lnText2;
    final iconColor =
        isActive ? LnColors.lnAccent2 : LnColors.lnText3;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Main row ────────────────────────────────────────────────────────
        MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: GestureDetector(
            onTap: () {
              setState(() => _isExpanded = !_isExpanded);
              ref
                  .read(selectedFolderIdProvider.notifier)
                  .select(widget.folder.folderId);
              context.go(
                '${RouteNames.appFolders}/${widget.folder.folderId}',
              );
            },
            onDoubleTap: _startRename,
            onSecondaryTapDown: (d) =>
                _showContextMenu(d.globalPosition),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 80),
              color: bgColor,
              padding: EdgeInsets.only(
                left: widget.depth * 14.0,
                right: 4,
                top: 1,
                bottom: 1,
              ),
              child: Row(
                children: [
                  // Chevron
                  SizedBox(
                    width: 20,
                    child: AnimatedRotation(
                      turns: _isExpanded ? 0.25 : 0.0,
                      duration: const Duration(milliseconds: 150),
                      child: Icon(
                        Icons.chevron_right,
                        size: 14,
                        color: iconColor,
                      ),
                    ),
                  ),
                  // Folder icon
                  Icon(
                    _isExpanded
                        ? Icons.folder_open_outlined
                        : Icons.folder_outlined,
                    size: 14,
                    color: iconColor,
                  ),
                  const SizedBox(width: 6),
                  // Name or rename field
                  Expanded(
                    child: _isRenaming
                        ? _RenameField(
                            controller: _renameController,
                            focusNode: _renameFocus,
                            onCommit: _commitRename,
                            onCancel: _cancelRename,
                          )
                        : Text(
                            widget.folder.name,
                            style: LnTextStyles.sidebarFolder(
                              color: textColor,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                  ),
                  // ··· button
                  AnimatedOpacity(
                    opacity: _isHovered || isActive ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 120),
                    child: _MoreButton(
                      onTap: (pos) => _showContextMenu(pos),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // ── Children ────────────────────────────────────────────────────────
        if (_isExpanded)
          ...children.map(
            (child) => FolderTreeTile(
              key: ValueKey(child.folderId),
              folder: child,
              depth: widget.depth + 1,
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Rename text field
// ---------------------------------------------------------------------------

class _RenameField extends StatelessWidget {
  const _RenameField({
    required this.controller,
    required this.focusNode,
    required this.onCommit,
    required this.onCancel,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onCommit;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): onCancel,
      },
      child: SizedBox(
        height: 22,
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w400,
            color: LnColors.lnText,
          ),
          decoration: const InputDecoration(
            contentPadding:
                EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            isDense: true,
            filled: true,
            fillColor: LnColors.lnSurface3,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(4)),
              borderSide: BorderSide(color: LnColors.lnAccent),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(4)),
              borderSide: BorderSide(color: LnColors.lnAccent),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(4)),
              borderSide: BorderSide(color: LnColors.lnAccent),
            ),
          ),
          onSubmitted: (_) => onCommit(),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ··· more button
// ---------------------------------------------------------------------------

class _MoreButton extends StatefulWidget {
  const _MoreButton({required this.onTap});

  final void Function(Offset globalPosition) onTap;

  @override
  State<_MoreButton> createState() => _MoreButtonState();
}

class _MoreButtonState extends State<_MoreButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTapDown: (d) => widget.onTap(d.globalPosition),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          decoration: BoxDecoration(
            color: _hovered
                ? LnColors.lnSurface3
                : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Icon(
            Icons.more_horiz,
            size: 14,
            color: LnColors.lnText3,
          ),
        ),
      ),
    );
  }
}
