import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../theme/colour_tokens.dart';
import '../../../theme/text_styles.dart';
import '../../folders/providers/folder_provider.dart';
import '../../notes/models/note.dart';
import '../../notes/providers/note_provider.dart';
import '../providers/search_provider.dart';
import '../widgets/attachment_result_row.dart';
import '../widgets/folder_result_row.dart';
import '../widgets/note_result_row.dart';
import '../widgets/search_filter_chips.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  late TextEditingController _controller;
  late FocusNode _inputFocus;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _inputFocus = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(searchProvider.notifier).open();
      _inputFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  void _navigateToResult(Object result) {
    if (result is FolderSearchResult) {
      ref.read(selectedFolderIdProvider.notifier).select(result.folder.folderId);
      ref.read(noteProvider.notifier).loadNotes(result.folder.folderId);
      context.go('/app');
      return;
    }

    final note = switch (result) {
      final NoteSearchResult r => r.note,
      final AttachmentSearchResult r => r.parentNote,
      final Note n => n,
      _ => null,
    };
    if (note == null) return;

    ref.read(selectedFolderIdProvider.notifier).select(note.folderId);
    ref.read(selectedNoteIdProvider.notifier).select(note.noteId);
    ref.read(noteProvider.notifier).loadNotes(note.folderId);
    context.go('/app/notes/${note.noteId}');
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(searchProvider);

    return Scaffold(
      backgroundColor: LnColors.lnBg,
      body: SafeArea(
        child: Column(
          children: [
            // Input row
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                decoration: BoxDecoration(
                  color: LnColors.lnSurface2,
                  border: Border.all(color: LnColors.lnBorder2),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search, size: 18, color: LnColors.lnText3),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        focusNode: _inputFocus,
                        style: LnTextStyles.bodyCompact(),
                        cursorColor: LnColors.lnAccent,
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Search…',
                          hintStyle:
                              LnTextStyles.bodyCompact(color: LnColors.lnText3),
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        onChanged: (v) =>
                            ref.read(searchProvider.notifier).setQuery(v),
                      ),
                    ),
                    if (_controller.text.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          _controller.clear();
                          ref.read(searchProvider.notifier).setQuery('');
                        },
                        child: const Icon(Icons.close,
                            size: 16, color: LnColors.lnText3),
                      ),
                  ],
                ),
              ),
            ),
            // Filter chips
            const SearchFilterChips(),
            // Results
            Expanded(child: _buildResults(state)),
          ],
        ),
      ),
    );
  }

  Widget _buildResults(SearchState state) {
    final query = state.query;
    final results = state.results;

    if (query.isEmpty) {
      if (results.recentNotes.isEmpty) {
        return Center(
          child: Text(
            'Start typing to search',
            style: LnTextStyles.bodyCompact(color: LnColors.lnText3),
          ),
        );
      }
      return ListView.builder(
        itemCount: results.recentNotes.length + 1,
        itemBuilder: (ctx, i) {
          if (i == 0) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text('RECENT', style: LnTextStyles.sectionLabel()),
            );
          }
          final note = results.recentNotes[i - 1];
          return NoteResultRow(
            result: NoteSearchResult(
              note: note,
              titleMatchRanges: const [],
              folderPath: '',
            ),
            isActive: false,
            onTap: () => _navigateToResult(note),
          );
        },
      );
    }

    final hasFolders = results.folders.isNotEmpty;
    final hasNotes = results.notes.isNotEmpty;
    final hasAttachments = results.attachments.isNotEmpty;
    if (!hasFolders && !hasNotes && !hasAttachments) {
      return Center(
        child: Text(
          'No results for "$query"',
          style: LnTextStyles.bodyCompact(color: LnColors.lnText3),
        ),
      );
    }

    final items = <Object>[];
    if (hasFolders) {
      items.add('FOLDERS');
      items.addAll(results.folders);
    }
    if (hasNotes) {
      items.add('NOTES');
      items.addAll(results.notes);
    }
    if (hasAttachments) {
      items.add('ATTACHMENTS');
      items.addAll(results.attachments);
    }

    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (ctx, i) {
        final item = items[i];
        if (item is String) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(item, style: LnTextStyles.sectionLabel()),
          );
        }
        if (item is FolderSearchResult) {
          return FolderResultRow(
            result: item,
            isActive: false,
            onTap: () => _navigateToResult(item),
          );
        }
        if (item is NoteSearchResult) {
          return NoteResultRow(
            result: item,
            isActive: false,
            onTap: () => _navigateToResult(item),
          );
        }
        if (item is AttachmentSearchResult) {
          return AttachmentResultRow(
            result: item,
            isActive: false,
            onTap: () => _navigateToResult(item),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}
