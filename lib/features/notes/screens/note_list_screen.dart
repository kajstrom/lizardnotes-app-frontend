import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../router/app_router.dart';
import '../../../theme/colour_tokens.dart';
import '../../../theme/text_styles.dart';
import '../../folders/models/folder.dart';
import '../../folders/providers/folder_provider.dart';
import '../providers/note_provider.dart';
import '../widgets/note_actions_sheet.dart';
import '../widgets/note_tile.dart';

class NoteListScreen extends ConsumerStatefulWidget {
  const NoteListScreen({super.key, required this.folderId});

  final String folderId;

  @override
  ConsumerState<NoteListScreen> createState() => _NoteListScreenState();
}

class _NoteListScreenState extends ConsumerState<NoteListScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
        () => ref.read(noteProvider.notifier).loadNotes(widget.folderId));
  }

  @override
  void didUpdateWidget(NoteListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.folderId != widget.folderId) {
      Future.microtask(
          () => ref.read(noteProvider.notifier).loadNotes(widget.folderId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final folderId = widget.folderId;
    final noteState = ref.watch(noteProvider);
    final folderState = ref.watch(folderProvider);

    final folder = folderState.folders
        .cast<Folder?>()
        .firstWhere(
          (f) => f?.folderId == folderId,
          orElse: () => null,
        );

    return Scaffold(
      backgroundColor: LnColors.lnBg,
      appBar: AppBar(
        backgroundColor: LnColors.lnSurface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: LnColors.lnText2),
          tooltip: 'Folders',
          onPressed: () => context.go(RouteNames.appFolders),
        ),
        title: Text(
          folder?.name ?? 'Notes',
          style: LnTextStyles.noteCardTitle(color: LnColors.lnText).copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: LnColors.lnBorder),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Meta strip ──────────────────────────────────────────────────────
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: LnColors.lnBorder, width: 1),
              ),
            ),
            child: Text(
              '${noteState.notes.length} '
              '${noteState.notes.length == 1 ? 'NOTE' : 'NOTES'} '
              '\u00b7 SORTED BY MODIFIED',
              style: LnTextStyles.sectionLabel(),
            ),
          ),
          // ── Note list ────────────────────────────────────────────────────────
          Expanded(
            child: noteState.status == NoteStatus.loading &&
                    noteState.notes.isEmpty
                ? const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: LnColors.lnAccent,
                    ),
                  )
                : noteState.notes.isEmpty
                    ? Padding(
                        padding:
                            const EdgeInsets.fromLTRB(24, 40, 24, 0),
                        child: Text(
                          'This folder is empty. Create your first note.',
                          style: LnTextStyles.authSubtitle(
                              color: LnColors.lnText3),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 8),
                        itemCount: noteState.notes.length,
                        itemBuilder: (context, i) {
                          final note = noteState.notes[i];
                          return Padding(
                            padding:
                                const EdgeInsets.symmetric(vertical: 2),
                            child: NoteTile(
                              note: note,
                              isActive: false,
                              onTap: () {
                                ref
                                    .read(selectedNoteIdProvider.notifier)
                                    .select(note.noteId);
                                context.go(
                                  RouteNames.appNote.replaceAll(
                                      ':noteId', note.noteId),
                                );
                              },
                              onLongPress: () => showNoteActionsSheet(
                                context: context,
                                note: note,
                                ref: ref,
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: LnColors.lnAccent,
        foregroundColor: LnColors.lnText,
        onPressed: () async {
          await ref
              .read(noteProvider.notifier)
              .createNote(folderId, 'Untitled');
        },
        child: const Icon(Icons.add, size: 24),
      ),
    );
  }
}
