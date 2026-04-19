import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../theme/colour_tokens.dart';
import '../../../theme/text_styles.dart';
import '../../folders/providers/folder_provider.dart';
import '../../notes/models/note.dart';
import '../../notes/providers/note_provider.dart';
import '../providers/search_provider.dart';
import 'attachment_result_row.dart';
import 'folder_result_row.dart';
import 'note_result_row.dart';
import 'search_filter_chips.dart';

/// Desktop-only search modal opened by ⌘K / Ctrl+K.
///
/// Use [showSearchModal] to display it so the barrier colour is set correctly.
class SearchModal extends ConsumerStatefulWidget {
  const SearchModal({super.key});

  @override
  ConsumerState<SearchModal> createState() => _SearchModalState();
}

class _SearchModalState extends ConsumerState<SearchModal> {
  late TextEditingController _controller;
  late FocusNode _inputFocus;
  final ScrollController _scrollController = ScrollController();

  /// Index of the keyboard-highlighted result row (−1 = none).
  int _cursorIndex = -1;

  /// Flat list of visible result items (NoteSearchResult | AttachmentSearchResult | Note).
  /// Rebuilt every time the search state changes.
  List<Object> _flatResults = const [];

  /// Cache key for (query, filter) used to detect when cursor should reset.
  String? _lastSearchKey;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _inputFocus = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) => _inputFocus.requestFocus());
  }

  @override
  void dispose() {
    _controller.dispose();
    _inputFocus.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Keyboard navigation
  // ---------------------------------------------------------------------------

  void _moveCursor(int delta) {
    if (_flatResults.isEmpty) return;
    setState(() {
      if (_cursorIndex == -1) {
        _cursorIndex = delta > 0 ? 0 : _flatResults.length - 1;
      } else {
        _cursorIndex =
            (_cursorIndex + delta).clamp(0, _flatResults.length - 1);
      }
      _scrollToCursor();
    });
  }

  void _scrollToCursor() {
    if (_cursorIndex < 0 || !_scrollController.hasClients) return;
    const estimatedItemHeight = 72.0;
    final target = (_cursorIndex * estimatedItemHeight)
        .clamp(0.0, _scrollController.position.maxScrollExtent);
    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 80),
      curve: Curves.easeOut,
    );
  }

  void _activateCursor(BuildContext ctx) {
    if (_cursorIndex < 0 || _cursorIndex >= _flatResults.length) return;
    _navigateToResult(ctx, _flatResults[_cursorIndex]);
  }

  void _closeModal(BuildContext ctx) {
    ref.read(searchProvider.notifier).close();
    Navigator.of(ctx).pop();
  }

  // ---------------------------------------------------------------------------
  // Navigation
  // ---------------------------------------------------------------------------

  void _navigateToResult(BuildContext ctx, Object result) {
    if (result is FolderSearchResult) {
      ref.read(selectedFolderIdProvider.notifier).select(result.folder.folderId);
      ref.read(noteProvider.notifier).loadNotes(result.folder.folderId);
      ref.read(searchProvider.notifier).close();
      Navigator.of(ctx).pop();
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
    ref.read(searchProvider.notifier).close();
    Navigator.of(ctx).pop();
    ctx.go('/app/notes/${note.noteId}');
  }

  // ---------------------------------------------------------------------------
  // Build helpers
  // ---------------------------------------------------------------------------

  List<Object> _buildFlatResults(SearchState state) {
    if (state.query.isEmpty) {
      return state.results.recentNotes;
    }
    return [
      ...state.results.folders,
      ...state.results.notes,
      ...state.results.attachments,
    ];
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(searchProvider);

    // Reset cursor whenever query or filter changes.
    final searchKey = '${state.query}|${state.activeFilter.name}';
    if (searchKey != _lastSearchKey) {
      _lastSearchKey = searchKey;
      _cursorIndex = -1;
    }
    _flatResults = _buildFlatResults(state);

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 620,
          maxHeight: MediaQuery.of(context).size.height * 0.78,
        ),
        child: Material(
          color: Colors.transparent,
          child: FocusScope(
            onKeyEvent: (node, event) {
              if (event is! KeyDownEvent) return KeyEventResult.ignored;
              switch (event.logicalKey) {
                case LogicalKeyboardKey.arrowDown:
                  _moveCursor(1);
                  return KeyEventResult.handled;
                case LogicalKeyboardKey.arrowUp:
                  _moveCursor(-1);
                  return KeyEventResult.handled;
                case LogicalKeyboardKey.enter:
                  _activateCursor(context);
                  return KeyEventResult.handled;
                case LogicalKeyboardKey.escape:
                  _closeModal(context);
                  return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: Container(
              decoration: BoxDecoration(
                color: LnColors.lnSurface2,
                border: Border.all(color: LnColors.lnBorder3),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildInputRow(context),
                  const Divider(color: LnColors.lnBorder, height: 1),
                  const SearchFilterChips(),
                  Flexible(child: _buildResults(context, state)),
                  const Divider(color: LnColors.lnBorder, height: 1),
                  _buildFooter(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputRow(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const Icon(Icons.search, size: 18, color: LnColors.lnText3),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _inputFocus,
              autofocus: true,
              style: LnTextStyles.bodyCompact(),
              cursorColor: LnColors.lnAccent,
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: 'Search notes, folders, attachments…',
                hintStyle: LnTextStyles.bodyCompact(color: LnColors.lnText3),
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: (v) {
                setState(() => _cursorIndex = -1);
                ref.read(searchProvider.notifier).setQuery(v);
              },
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: LnColors.lnSurface3,
              border: Border.all(color: LnColors.lnBorder2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text('ESC', style: LnTextStyles.sectionLabel()),
          ),
        ],
      ),
    );
  }

  Widget _buildResults(BuildContext context, SearchState state) {
    final query = state.query;
    final results = state.results;

    if (query.isEmpty) {
      if (results.recentNotes.isEmpty) {
        return const _EmptyHint(text: 'Start typing to search');
      }
      return ListView.builder(
        controller: _scrollController,
        shrinkWrap: true,
        itemCount: results.recentNotes.length + 1,
        itemBuilder: (ctx, i) {
          if (i == 0) return _sectionLabel('RECENT');
          final note = results.recentNotes[i - 1];
          final flatIdx = i - 1;
          return NoteResultRow(
            result: NoteSearchResult(
              note: note,
              titleMatchRanges: const [],
              folderPath: '',
            ),
            isActive: _cursorIndex == flatIdx,
            onTap: () => _navigateToResult(context, note),
          );
        },
      );
    }

    final hasFolders = results.folders.isNotEmpty;
    final hasNotes = results.notes.isNotEmpty;
    final hasAttachments = results.attachments.isNotEmpty;
    if (!hasFolders && !hasNotes && !hasAttachments) {
      return _EmptyHint(text: 'No results for "$query"');
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

    // Track the index offset for result items (excluding section headers).
    var resultIdx = 0;

    return ListView.builder(
      controller: _scrollController,
      shrinkWrap: true,
      itemCount: items.length,
      itemBuilder: (ctx, i) {
        final item = items[i];
        if (item is String) {
          return _sectionLabel(item);
        }
        final currentIdx = resultIdx++;
        if (item is FolderSearchResult) {
          return FolderResultRow(
            result: item,
            isActive: _cursorIndex == currentIdx,
            onTap: () => _navigateToResult(context, item),
          );
        }
        if (item is NoteSearchResult) {
          return NoteResultRow(
            result: item,
            isActive: _cursorIndex == currentIdx,
            onTap: () => _navigateToResult(context, item),
          );
        }
        if (item is AttachmentSearchResult) {
          return AttachmentResultRow(
            result: item,
            isActive: _cursorIndex == currentIdx,
            onTap: () => _navigateToResult(context, item),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Text(text.toUpperCase(), style: LnTextStyles.sectionLabel()),
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text(
            '↑↓ navigate    ↵ open    Esc dismiss',
            style: LnTextStyles.sectionLabel(),
          ),
        ],
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Text(text, style: LnTextStyles.bodyCompact(color: LnColors.lnText3)),
      ),
    );
  }
}
