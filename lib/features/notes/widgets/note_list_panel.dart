import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../router/app_router.dart';
import '../../../theme/colour_tokens.dart';
import '../../../theme/text_styles.dart';
import '../../folders/models/folder.dart';
import '../../folders/providers/folder_provider.dart';
import '../models/note.dart';
import '../providers/note_provider.dart';
import 'note_context_menu.dart';
import 'note_delete_confirm_dialog.dart';
import 'note_move_dialog.dart';
import 'note_tile.dart';

class NoteListPanel extends ConsumerStatefulWidget {
  const NoteListPanel({super.key});

  @override
  ConsumerState<NoteListPanel> createState() => _NoteListPanelState();
}

class _NoteListPanelState extends ConsumerState<NoteListPanel> {
  String? _lastFolderId;
  // Maps noteId → rename controller for inline renaming.
  final Map<String, TextEditingController> _renameControllers = {};
  String? _renamingNoteId;
  final FocusNode _renameFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _renameFocus.addListener(_onRenameFocusChange);
  }

  @override
  void dispose() {
    _renameFocus
      ..removeListener(_onRenameFocusChange)
      ..dispose();
    for (final c in _renameControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final folderId = ref.read(selectedFolderIdProvider);
    if (folderId != null && folderId != _lastFolderId) {
      _lastFolderId = folderId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(noteProvider.notifier).loadNotes(folderId);
        }
      });
    }
  }

  void _startRename(Note note) {
    final controller = TextEditingController(text: note.title);
    _renameControllers[note.noteId] = controller;
    setState(() => _renamingNoteId = note.noteId);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _renameFocus.requestFocus();
      controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: controller.text.length,
      );
    });
  }

  void _commitRename(Note note) {
    if (_renamingNoteId != note.noteId) return;
    final controller = _renameControllers[note.noteId];
    final newTitle = controller?.text.trim() ?? '';
    setState(() => _renamingNoteId = null);
    _renameControllers.remove(note.noteId)?.dispose();
    if (newTitle.isNotEmpty && newTitle != note.title) {
      ref.read(noteProvider.notifier).renameNote(note.noteId, newTitle);
    }
  }

  void _cancelRename(Note note) {
    if (_renamingNoteId != note.noteId) return;
    setState(() => _renamingNoteId = null);
    _renameControllers.remove(note.noteId)?.dispose();
  }

  void _onRenameFocusChange() {
    if (!_renameFocus.hasFocus && _renamingNoteId != null) {
      final noteState = ref.read(noteProvider);
      final note = noteState.notes
          .cast<Note?>()
          .firstWhere((n) => n?.noteId == _renamingNoteId, orElse: () => null);
      if (note != null) _commitRename(note);
    }
  }

  Future<void> _handleContextMenu(
      BuildContext ctx, Note note, Offset position) async {
    final action =
        await showNoteContextMenu(context: ctx, globalPosition: position);
    if (!mounted) return;

    switch (action) {
      case NoteMenuAction.rename:
        _startRename(note);
      case NoteMenuAction.moveTo:
        if (!mounted) return;
        // ignore: use_build_context_synchronously
        await showNoteMoveDialog(context: context, note: note);
      case NoteMenuAction.copyLink:
        await Clipboard.setData(
          ClipboardData(text: '/app/notes/${note.noteId}'),
        );
      case NoteMenuAction.delete:
        if (!mounted) return;
        // ignore: use_build_context_synchronously
        await showNoteDeleteConfirmDialog(context: context, note: note);
      case null:
        break;
    }
  }

  void _createNote(String folderId) async {
    final created =
        await ref.read(noteProvider.notifier).createNote(folderId, 'Untitled');
    if (created != null && mounted) {
      ref.read(selectedNoteIdProvider.notifier).select(created.noteId);
      context.go(RouteNames.appNote.replaceAll(':noteId', created.noteId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedFolderId = ref.watch(selectedFolderIdProvider);
    final noteState = ref.watch(noteProvider);
    final folderState = ref.watch(folderProvider);
    final selectedNoteId = ref.watch(selectedNoteIdProvider);

    // Also watch selectedFolderIdProvider to react to changes.
    ref.listen(selectedFolderIdProvider, (previous, next) {
      if (next != null && next != previous) {
        _lastFolderId = next;
        ref.read(noteProvider.notifier).loadNotes(next);
      }
    });

    final folder = selectedFolderId != null
        ? folderState.folders
            .cast<Folder?>()
            .firstWhere(
              (f) => f?.folderId == selectedFolderId,
              orElse: () => null,
            )
        : null;

    if (selectedFolderId == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Header ────────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 8, 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      folder?.name ?? 'Notes',
                      style: LnTextStyles.noteCardTitle(
                        color: LnColors.lnText,
                      ).copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${noteState.notes.length} '
                      '${noteState.notes.length == 1 ? 'note' : 'notes'}',
                      style: LnTextStyles.sectionLabel(),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add, size: 16, color: LnColors.lnText2),
                tooltip: 'New note',
                splashRadius: 14,
                onPressed: () => _createNote(selectedFolderId),
              ),
            ],
          ),
        ),
        // ── Sort row ──────────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: LnColors.lnBorder, width: 1),
            ),
          ),
          child: Text(
            'SORT: MODIFIED \u2193',
            style: LnTextStyles.sectionLabel(),
          ),
        ),
        // ── Note list ─────────────────────────────────────────────────────────
        Expanded(
          child: noteState.status == NoteStatus.loading && noteState.notes.isEmpty
              ? const Center(
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: LnColors.lnAccent,
                    ),
                  ),
                )
              : noteState.notes.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(14, 40, 14, 0),
                      child: Text(
                        'This folder is empty. Create your first note.',
                        style: LnTextStyles.authSubtitle(
                            color: LnColors.lnText3),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 6),
                      itemCount: noteState.notes.length,
                      itemBuilder: (context, i) {
                        final note = noteState.notes[i];
                        final isActive = selectedNoteId == note.noteId;
                        final isRenaming = _renamingNoteId == note.noteId;

                        if (isRenaming) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            child: CallbackShortcuts(
                              bindings: {
                                const SingleActivator(LogicalKeyboardKey.enter):
                                    () => _commitRename(note),
                                const SingleActivator(LogicalKeyboardKey.escape):
                                    () => _cancelRename(note),
                              },
                              child: TextField(
                                controller:
                                    _renameControllers[note.noteId],
                                focusNode: _renameFocus,
                                style: LnTextStyles.noteCardTitle(),
                                decoration: InputDecoration(
                                  isDense: true,
                                  contentPadding:
                                      const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 6,
                                  ),
                                  filled: true,
                                  fillColor: LnColors.lnSurface2,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(4),
                                    borderSide: const BorderSide(
                                        color: LnColors.lnAccent),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(4),
                                    borderSide: const BorderSide(
                                        color: LnColors.lnAccent),
                                  ),
                                ),
                                onSubmitted: (_) => _commitRename(note),
                              ),
                            ),
                          );
                        }

                        return Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          child: NoteTile(
                            note: note,
                            isActive: isActive,
                            onTap: () {
                              ref
                                  .read(selectedNoteIdProvider.notifier)
                                  .select(note.noteId);
                              context.go(
                                RouteNames.appNote
                                    .replaceAll(':noteId', note.noteId),
                              );
                            },
                            onContextMenu: (pos) =>
                                _handleContextMenu(context, note, pos),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}
