import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../attachments/models/attachment.dart';
import '../../folders/models/folder.dart';
import '../../folders/providers/folder_provider.dart';
import '../../notes/models/note.dart';
import '../../notes/providers/note_provider.dart';
import 'attachment_registry_provider.dart';

// ---------------------------------------------------------------------------
// Filter
// ---------------------------------------------------------------------------

enum SearchFilter { all, notes, attachments, thisFolder }

// ---------------------------------------------------------------------------
// Result types
// ---------------------------------------------------------------------------

class NoteSearchResult {
  const NoteSearchResult({
    required this.note,
    required this.titleMatchRanges,
    this.matchSnippet,
    this.snippetMatchRanges = const [],
    required this.folderPath,
  });

  final Note note;
  final List<TextRange> titleMatchRanges;

  /// Excerpt from note.content centred on the first body match.
  /// Null when the match is title-only.
  final String? matchSnippet;
  final List<TextRange> snippetMatchRanges;
  final String folderPath;
}

class AttachmentSearchResult {
  const AttachmentSearchResult({
    required this.attachment,
    required this.parentNote,
    required this.folderPath,
    required this.filenameMatchRanges,
  });

  final Attachment attachment;
  final Note parentNote;
  final String folderPath;
  final List<TextRange> filenameMatchRanges;
}

class FolderSearchResult {
  const FolderSearchResult({
    required this.folder,
    required this.nameMatchRanges,
  });

  final Folder folder;
  final List<TextRange> nameMatchRanges;
}

class SearchResults {
  const SearchResults({
    this.recentNotes = const [],
    this.notes = const [],
    this.attachments = const [],
    this.folders = const [],
  });

  /// Shown when the query is empty — up to 8 notes sorted by updatedAt desc.
  final List<Note> recentNotes;
  final List<NoteSearchResult> notes;
  final List<AttachmentSearchResult> attachments;
  final List<FolderSearchResult> folders;

  static const empty = SearchResults();
}

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class SearchState {
  const SearchState({
    this.query = '',
    this.activeFilter = SearchFilter.all,
    this.results = SearchResults.empty,
    this.isOpen = false,
  });

  final String query;
  final SearchFilter activeFilter;
  final SearchResults results;
  final bool isOpen;

  SearchState copyWith({
    String? query,
    SearchFilter? activeFilter,
    SearchResults? results,
    bool? isOpen,
  }) =>
      SearchState(
        query: query ?? this.query,
        activeFilter: activeFilter ?? this.activeFilter,
        results: results ?? this.results,
        isOpen: isOpen ?? this.isOpen,
      );
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final searchProvider =
    NotifierProvider<SearchNotifier, SearchState>(SearchNotifier.new);

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class SearchNotifier extends Notifier<SearchState> {
  Timer? _debounce;

  @override
  SearchState build() {
    ref.onDispose(() => _debounce?.cancel());
    return const SearchState();
  }

  void setQuery(String q) {
    _debounce?.cancel();
    state = state.copyWith(query: q);
    _debounce = Timer(const Duration(milliseconds: 150), _runSearch);
  }

  void setFilter(SearchFilter filter) {
    _debounce?.cancel();
    state = state.copyWith(activeFilter: filter);
    _runSearch();
  }

  void open() {
    state = const SearchState(isOpen: true);
    // Populate recent notes immediately.
    state = state.copyWith(results: _recentResults());
  }

  void close() => state = state.copyWith(isOpen: false);

  // ---------------------------------------------------------------------------
  // Internal
  // ---------------------------------------------------------------------------

  void _runSearch() {
    final q = state.query.trim();
    if (q.isEmpty) {
      state = state.copyWith(results: _recentResults());
      return;
    }
    state = state.copyWith(results: _search(q));
  }

  SearchResults _recentResults() {
    final notes = List<Note>.from(ref.read(noteProvider).notes)
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return SearchResults(recentNotes: notes.take(8).toList());
  }

  SearchResults _search(String rawQuery) {
    // V1 NOTE: noteProvider holds only the notes for the currently loaded
    // folder. Title and body-text search is therefore limited to those notes;
    // notes in other folders will not appear in results until that folder is
    // opened. This is an accepted v1 constraint — the backend has no search
    // endpoint and full cross-folder indexing is deferred to a future release.
    final allNotes = ref.read(noteProvider).notes;
    final allFolders = ref.read(folderProvider).folders;
    final registry = ref.read(attachmentRegistryProvider);
    final selectedFolderId = ref.read(selectedFolderIdProvider);

    final lq = rawQuery.toLowerCase();

    List<Note> candidateNotes = allNotes;
    if (state.activeFilter == SearchFilter.thisFolder &&
        selectedFolderId != null) {
      candidateNotes =
          candidateNotes.where((n) => n.folderId == selectedFolderId).toList();
    }

    final noteResults = <NoteSearchResult>[];
    final includeNotes = state.activeFilter == SearchFilter.all ||
        state.activeFilter == SearchFilter.notes ||
        state.activeFilter == SearchFilter.thisFolder;

    if (includeNotes) {
      for (final note in candidateNotes) {
        final titleRanges = _findRanges(note.title, lq);
        final contentRanges = _findRanges(note.content, lq);
        if (titleRanges.isEmpty && contentRanges.isEmpty) continue;

        String? snippet;
        var snippetRanges = <TextRange>[];
        if (contentRanges.isNotEmpty) {
          final (s, r) = _buildSnippet(note.content, contentRanges.first, lq);
          snippet = s;
          snippetRanges = r;
        }

        noteResults.add(NoteSearchResult(
          note: note,
          titleMatchRanges: titleRanges,
          matchSnippet: snippet,
          snippetMatchRanges: snippetRanges,
          folderPath: _folderPath(note.folderId, allFolders),
        ));
      }
    }

    final attachmentResults = <AttachmentSearchResult>[];
    final includeAttachments = state.activeFilter == SearchFilter.all ||
        state.activeFilter == SearchFilter.attachments;

    if (includeAttachments) {
      for (final entry in registry.entries) {
        final noteId = entry.key;
        final parentNote = _findNote(allNotes, noteId);
        if (parentNote == null) continue;
        if (state.activeFilter == SearchFilter.thisFolder &&
            selectedFolderId != null &&
            parentNote.folderId != selectedFolderId) {
          continue;
        }
        for (final att in entry.value) {
          final ranges = _findRanges(att.filename, lq);
          if (ranges.isEmpty) continue;
          attachmentResults.add(AttachmentSearchResult(
            attachment: att,
            parentNote: parentNote,
            folderPath: _folderPath(parentNote.folderId, allFolders),
            filenameMatchRanges: ranges,
          ));
        }
      }
    }

    final folderResults = <FolderSearchResult>[];
    final includeFolders = state.activeFilter == SearchFilter.all ||
        state.activeFilter == SearchFilter.notes;

    if (includeFolders) {
      for (final folder in allFolders) {
        final ranges = _findRanges(folder.name, lq);
        if (ranges.isEmpty) continue;
        folderResults.add(FolderSearchResult(
          folder: folder,
          nameMatchRanges: ranges,
        ));
      }
    }

    return SearchResults(
      notes: noteResults,
      attachments: attachmentResults,
      folders: folderResults,
    );
  }

  List<TextRange> _findRanges(String text, String lowerQuery) {
    if (lowerQuery.isEmpty) return const [];
    final lowerText = text.toLowerCase();
    final ranges = <TextRange>[];
    var start = 0;
    while (true) {
      final idx = lowerText.indexOf(lowerQuery, start);
      if (idx == -1) break;
      ranges.add(TextRange(start: idx, end: idx + lowerQuery.length));
      start = idx + lowerQuery.length;
    }
    return ranges;
  }

  (String, List<TextRange>) _buildSnippet(
    String content,
    TextRange firstMatch,
    String lowerQuery,
  ) {
    const window = 80;
    final lo = (firstMatch.start - window).clamp(0, content.length);
    final hi = (firstMatch.end + window).clamp(0, content.length);
    final snippet = content.substring(lo, hi);
    return (snippet, _findRanges(snippet, lowerQuery));
  }

  String _folderPath(String folderId, List<Folder> folders) {
    final folder = _findFolder(folders, folderId);
    return folder?.path ?? '';
  }

  static Note? _findNote(List<Note> notes, String noteId) {
    for (final n in notes) {
      if (n.noteId == noteId) return n;
    }
    return null;
  }

  static Folder? _findFolder(List<Folder> folders, String folderId) {
    for (final f in folders) {
      if (f.folderId == folderId) return f;
    }
    return null;
  }
}
