import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/api_client.dart';
import '../models/note.dart';

// ---------------------------------------------------------------------------
// Selected note
// ---------------------------------------------------------------------------

/// The currently selected note ID. Updated when the user taps a note tile.
final selectedNoteIdProvider =
    NotifierProvider<SelectedNoteNotifier, String?>(
  SelectedNoteNotifier.new,
);

class SelectedNoteNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? id) => state = id;
}

// ---------------------------------------------------------------------------
// Note state
// ---------------------------------------------------------------------------

enum NoteStatus { idle, loading, error }

class NoteState {
  const NoteState({
    this.notes = const [],
    this.status = NoteStatus.idle,
    this.errorMessage,
    this.currentFolderId,
  });

  final List<Note> notes;
  final NoteStatus status;
  final String? errorMessage;
  final String? currentFolderId;

  NoteState copyWith({
    List<Note>? notes,
    NoteStatus? status,
    String? errorMessage,
    bool clearError = false,
    String? currentFolderId,
    bool clearFolderId = false,
  }) =>
      NoteState(
        notes: notes ?? this.notes,
        status: status ?? this.status,
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
        currentFolderId: clearFolderId
            ? null
            : (currentFolderId ?? this.currentFolderId),
      );
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final noteProvider =
    NotifierProvider<NoteNotifier, NoteState>(NoteNotifier.new);

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class NoteNotifier extends Notifier<NoteState> {
  ApiClient get _api => ref.read(apiClientProvider);

  @override
  NoteState build() => const NoteState();

  Future<void> loadNotes(String folderId) async {
    state = state.copyWith(
      status: NoteStatus.loading,
      clearError: true,
      currentFolderId: folderId,
    );
    try {
      final notes = await _api.getNotes(folderId: folderId);
      // Sort by updatedAt descending.
      final sorted = List<Note>.from(notes)
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      state = state.copyWith(notes: sorted, status: NoteStatus.idle);
    } catch (e) {
      state = state.copyWith(
        status: NoteStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  Future<Note?> createNote(String folderId, String title) async {
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final now = DateTime.now();
    final temp = Note(
      noteId: tempId,
      folderId: folderId,
      title: title,
      content: '',
      createdAt: now,
      updatedAt: now,
    );
    final previous = List<Note>.unmodifiable(state.notes);
    // Only add optimistically if the panel is currently showing this folder.
    if (state.currentFolderId == folderId) {
      state = state.copyWith(notes: [temp, ...state.notes]);
    }

    try {
      final created = await _api.createNote(folderId: folderId, title: title);
      if (state.currentFolderId == folderId) {
        state = state.copyWith(
          notes: state.notes
              .map((n) => n.noteId == tempId ? created : n)
              .toList(),
        );
      }
      return created;
    } catch (e) {
      if (state.currentFolderId == folderId) {
        state = state.copyWith(
          notes: List<Note>.from(previous),
          errorMessage: e.toString(),
        );
      }
      return null;
    }
  }

  Future<void> renameNote(String noteId, String newTitle) async {
    final previous = List<Note>.unmodifiable(state.notes);
    state = state.copyWith(
      notes: state.notes
          .map((n) => n.noteId == noteId ? n.copyWith(title: newTitle) : n)
          .toList(),
    );
    try {
      await _api.updateNote(noteId, title: newTitle);
    } catch (e) {
      state = state.copyWith(
        notes: List<Note>.from(previous),
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> moveNote(String noteId, String newFolderId) async {
    final previous = List<Note>.unmodifiable(state.notes);
    // Note is moving to another folder — remove from current list.
    state = state.copyWith(
      notes: state.notes.where((n) => n.noteId != noteId).toList(),
    );
    try {
      await _api.updateNote(noteId, folderId: newFolderId);
    } catch (e) {
      state = state.copyWith(
        notes: List<Note>.from(previous),
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> deleteNote(String noteId) async {
    final previous = List<Note>.unmodifiable(state.notes);
    final idx = state.notes.indexWhere((n) => n.noteId == noteId);
    state = state.copyWith(
      notes: state.notes.where((n) => n.noteId != noteId).toList(),
    );

    // Auto-select the next note if the deleted one was selected.
    final selectedId = ref.read(selectedNoteIdProvider);
    if (selectedId == noteId) {
      final remaining = state.notes;
      final nextId = remaining.isNotEmpty
          ? remaining[idx.clamp(0, remaining.length - 1)].noteId
          : null;
      ref.read(selectedNoteIdProvider.notifier).select(nextId);
    }

    try {
      await _api.deleteNote(noteId);
    } catch (e) {
      state = state.copyWith(
        notes: List<Note>.from(previous),
        errorMessage: e.toString(),
      );
    }
  }
}
