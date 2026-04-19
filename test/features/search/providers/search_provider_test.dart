import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lizardnotes_app/features/folders/models/folder.dart';
import 'package:lizardnotes_app/features/folders/providers/folder_provider.dart';
import 'package:lizardnotes_app/features/notes/models/note.dart';
import 'package:lizardnotes_app/features/notes/providers/note_provider.dart';
import 'package:lizardnotes_app/features/search/providers/search_provider.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Note _note(
  String id, {
  String title = 'Note',
  String content = '',
  String folderId = 'f1',
  DateTime? updatedAt,
}) =>
    Note(
      noteId: id,
      folderId: folderId,
      title: title,
      content: content,
      createdAt: DateTime(2024),
      updatedAt: updatedAt ?? DateTime(2024),
    );

// ---------------------------------------------------------------------------
// Fake notifiers
// ---------------------------------------------------------------------------

class _FakeNoteNotifier extends NoteNotifier {
  _FakeNoteNotifier(this._notes);
  final List<Note> _notes;

  @override
  NoteState build() => NoteState(notes: _notes);
}

class _FakeFolderNotifier extends FolderNotifier {
  _FakeFolderNotifier(this._folders);
  final List<Folder> _folders;

  @override
  FolderState build() => FolderState(folders: _folders);
}

class _FakeSelectedFolderNotifier extends SelectedFolderNotifier {
  _FakeSelectedFolderNotifier(this._id);
  final String? _id;

  @override
  String? build() => _id;
}

ProviderContainer _makeContainer({
  List<Note> notes = const [],
  List<Folder> folders = const [],
  String? selectedFolderId,
}) {
  return ProviderContainer(
    overrides: [
      noteProvider.overrideWith(() => _FakeNoteNotifier(notes)),
      folderProvider.overrideWith(() => _FakeFolderNotifier(folders)),
      selectedFolderIdProvider
          .overrideWith(() => _FakeSelectedFolderNotifier(selectedFolderId)),
    ],
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('SearchNotifier', () {
    test('empty query → recentNotes sorted by updatedAt desc, max 8', () {
      final notes = List.generate(
        10,
        (i) => _note(
          'n$i',
          title: 'Note $i',
          updatedAt: DateTime(2024, 1, i + 1),
        ),
      );
      final container = _makeContainer(notes: notes);
      addTearDown(container.dispose);

      container.read(searchProvider.notifier).open();
      final state = container.read(searchProvider);

      expect(state.results.recentNotes, hasLength(8));
      // Sorted descending: last updatedAt first.
      for (var i = 0; i < state.results.recentNotes.length - 1; i++) {
        expect(
          state.results.recentNotes[i].updatedAt
              .isAfter(state.results.recentNotes[i + 1].updatedAt),
          isTrue,
        );
      }
    });

    test('note title match → correct NoteSearchResult with matchRanges', () {
      final notes = [
        _note('n1', title: 'Flutter guide'),
        _note('n2', title: 'Dart handbook'),
      ];
      final container = _makeContainer(notes: notes);
      addTearDown(container.dispose);

      container.read(searchProvider.notifier).open();
      container.read(searchProvider.notifier).setQuery('Flutter');
      // Bypass debounce by calling _runSearch indirectly via setFilter (no debounce).
      // Or we trigger it by pumping the timer in fakeAsync below.

      // Use fakeAsync to advance past the 150ms debounce.
      fakeAsync((async) {
        final c2 = _makeContainer(notes: notes);
        addTearDown(c2.dispose);
        c2.read(searchProvider.notifier).open();
        c2.read(searchProvider.notifier).setQuery('flutter');

        async.elapse(const Duration(milliseconds: 150));

        final state = c2.read(searchProvider);
        expect(state.results.notes, hasLength(1));
        expect(state.results.notes[0].note.noteId, 'n1');
        expect(state.results.notes[0].titleMatchRanges, hasLength(1));
        expect(state.results.notes[0].titleMatchRanges[0].start, 0);
        expect(
          state.results.notes[0].titleMatchRanges[0].end,
          'flutter'.length,
        );
      });
    });

    test('"This folder" filter restricts results to selected folder', () {
      final notes = [
        _note('n1', title: 'Alpha note', folderId: 'f1'),
        _note('n2', title: 'Alpha note', folderId: 'f2'),
      ];
      fakeAsync((async) {
        final container = _makeContainer(
          notes: notes,
          selectedFolderId: 'f1',
        );
        addTearDown(container.dispose);

        container.read(searchProvider.notifier).open();
        container.read(searchProvider.notifier).setQuery('alpha');
        async.elapse(const Duration(milliseconds: 150));

        // Without filter: both notes returned.
        var state = container.read(searchProvider);
        expect(state.results.notes, hasLength(2));

        // Apply thisFolder filter.
        container.read(searchProvider.notifier).setFilter(SearchFilter.thisFolder);

        state = container.read(searchProvider);
        expect(state.results.notes, hasLength(1));
        expect(state.results.notes[0].note.noteId, 'n1');
      });
    });

    test('setQuery debounce: search does not fire until 150ms', () {
      final notes = [_note('n1', title: 'hello world')];

      fakeAsync((async) {
        final container = _makeContainer(notes: notes);
        addTearDown(container.dispose);

        container.read(searchProvider.notifier).open();
        container.read(searchProvider.notifier).setQuery('hello');

        // Query updated but results not yet populated.
        expect(container.read(searchProvider).query, 'hello');
        expect(container.read(searchProvider).results.notes, isEmpty);

        // Still not fired after 149ms.
        async.elapse(const Duration(milliseconds: 149));
        expect(container.read(searchProvider).results.notes, isEmpty);

        // Fires after the remaining 1ms.
        async.elapse(const Duration(milliseconds: 1));
        expect(container.read(searchProvider).results.notes, hasLength(1));
      });
    });

    test('debounce resets on rapid successive keystrokes', () {
      final notes = [
        _note('n1', title: 'hello'),
        _note('n2', title: 'world'),
      ];

      fakeAsync((async) {
        final container = _makeContainer(notes: notes);
        addTearDown(container.dispose);

        container.read(searchProvider.notifier).open();
        container.read(searchProvider.notifier).setQuery('h');
        async.elapse(const Duration(milliseconds: 100));
        // Type another character — should reset the debounce timer.
        container.read(searchProvider.notifier).setQuery('he');
        async.elapse(const Duration(milliseconds: 149));
        // Should still be empty — timer reset to 150ms from 'he' keystroke.
        expect(container.read(searchProvider).results.notes, isEmpty);

        async.elapse(const Duration(milliseconds: 1));
        expect(container.read(searchProvider).results.notes, hasLength(1));
        expect(container.read(searchProvider).results.notes[0].note.noteId, 'n1');
      });
    });
  });
}
