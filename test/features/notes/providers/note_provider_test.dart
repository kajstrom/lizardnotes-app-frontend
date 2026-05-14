import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lizardnotes_app/api/api_client.dart';
import 'package:lizardnotes_app/features/notes/models/note.dart';
import 'package:lizardnotes_app/features/notes/providers/note_provider.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Mock
// ---------------------------------------------------------------------------

class MockApiClient extends Mock implements ApiClient {}

Note _makeNote(
  String id, {
  String folderId = 'folder1',
  String title = 'Note',
  String content = '',
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

ProviderContainer _makeContainer(ApiClient client) {
  return ProviderContainer(
    overrides: [apiClientProvider.overrideWithValue(client)],
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    registerFallbackValue(_makeNote('fallback'));
  });

  group('NoteNotifier.loadNotes', () {
    test('populates notes sorted by updatedAt descending', () async {
      final client = MockApiClient();
      final older = _makeNote('n1', title: 'Older',
          updatedAt: DateTime(2024, 1, 1));
      final newer = _makeNote('n2', title: 'Newer',
          updatedAt: DateTime(2024, 6, 1));
      when(() => client.getNotes(folderId: any(named: 'folderId')))
          .thenAnswer((_) async => [older, newer]);

      final container = _makeContainer(client);
      addTearDown(container.dispose);

      await container.read(noteProvider.notifier).loadNotes('folder1');

      final state = container.read(noteProvider);
      expect(state.status, NoteStatus.idle);
      expect(state.notes, hasLength(2));
      // Newer first.
      expect(state.notes.first.noteId, 'n2');
      expect(state.notes.last.noteId, 'n1');
    });

    test('transitions to error when API throws', () async {
      final client = MockApiClient();
      when(() => client.getNotes(folderId: any(named: 'folderId')))
          .thenThrow(const ApiException(500, 'Internal error', 'getNotes'));

      final container = _makeContainer(client);
      addTearDown(container.dispose);

      await container.read(noteProvider.notifier).loadNotes('folder1');

      final state = container.read(noteProvider);
      expect(state.status, NoteStatus.error);
      expect(state.errorMessage, isNotNull);
    });
  });

  group('NoteNotifier.createNote', () {
    test('optimistic update adds note before API completes', () async {
      final client = MockApiClient();
      final created = _makeNote('real-1', title: 'Untitled');
      final apiCompleter = Completer<Note>();

      when(() => client.getNotes(folderId: any(named: 'folderId')))
          .thenAnswer((_) async => []);
      when(
        () => client.createNote(
          folderId: any(named: 'folderId'),
          title: any(named: 'title'),
        ),
      ).thenAnswer((_) => apiCompleter.future);

      final container = _makeContainer(client);
      addTearDown(container.dispose);
      await container.read(noteProvider.notifier).loadNotes('folder1');

      final future = container.read(noteProvider.notifier)
          .createNote('folder1', 'Untitled');

      // Optimistic entry added before API resolves.
      final optimistic = container.read(noteProvider).notes;
      expect(optimistic, isNotEmpty);
      expect(
          optimistic.any((n) => n.noteId.startsWith('temp_')), isTrue);

      apiCompleter.complete(created);
      await future;

      final finalState = container.read(noteProvider);
      expect(finalState.notes.any((n) => n.noteId == 'real-1'), isTrue);
      expect(
          finalState.notes.any((n) => n.noteId.startsWith('temp_')),
          isFalse);
    });

    test('rolls back on API error', () async {
      final client = MockApiClient();
      when(() => client.getNotes(folderId: any(named: 'folderId')))
          .thenAnswer((_) async => []);
      when(() => client.createNote(
            folderId: any(named: 'folderId'),
            title: any(named: 'title'),
          )).thenThrow(
          const ApiException(500, 'Server error', 'createNote'));

      final container = _makeContainer(client);
      addTearDown(container.dispose);
      await container.read(noteProvider.notifier).loadNotes('folder1');

      await container.read(noteProvider.notifier)
          .createNote('folder1', 'Untitled');

      expect(container.read(noteProvider).notes, isEmpty);
    });
  });

  group('NoteNotifier.deleteNote', () {
    test('removes note from state', () async {
      final client = MockApiClient();
      final notes = [
        _makeNote('n1', title: 'Note 1',
            updatedAt: DateTime(2024, 6, 1)),
        _makeNote('n2', title: 'Note 2',
            updatedAt: DateTime(2024, 5, 1)),
        _makeNote('n3', title: 'Note 3',
            updatedAt: DateTime(2024, 4, 1)),
      ];

      when(() => client.getNotes(folderId: any(named: 'folderId')))
          .thenAnswer((_) async => notes);
      when(() => client.deleteNote(any())).thenAnswer((_) async {});

      final container = _makeContainer(client);
      addTearDown(container.dispose);
      await container.read(noteProvider.notifier).loadNotes('folder1');

      await container.read(noteProvider.notifier).deleteNote('n2');

      final remaining = container.read(noteProvider).notes.map((n) => n.noteId);
      expect(remaining, containsAll(['n1', 'n3']));
      expect(remaining, isNot(contains('n2')));
    });

    test('auto-selects next note when deleted note was selected', () async {
      final client = MockApiClient();
      final notes = [
        _makeNote('n1', updatedAt: DateTime(2024, 6, 1)),
        _makeNote('n2', updatedAt: DateTime(2024, 5, 1)),
        _makeNote('n3', updatedAt: DateTime(2024, 4, 1)),
      ];

      when(() => client.getNotes(folderId: any(named: 'folderId')))
          .thenAnswer((_) async => notes);
      when(() => client.deleteNote(any())).thenAnswer((_) async {});

      final container = _makeContainer(client);
      addTearDown(container.dispose);
      await container.read(noteProvider.notifier).loadNotes('folder1');

      // Select n2 (index 1).
      container.read(selectedNoteIdProvider.notifier).select('n2');

      await container.read(noteProvider.notifier).deleteNote('n2');

      // After deleting n2 (was at index 1), index 1 is now n3.
      final selectedId = container.read(selectedNoteIdProvider);
      expect(selectedId, 'n3');
    });

    test('clears selection when last note is deleted', () async {
      final client = MockApiClient();
      final notes = [_makeNote('n1')];

      when(() => client.getNotes(folderId: any(named: 'folderId')))
          .thenAnswer((_) async => notes);
      when(() => client.deleteNote(any())).thenAnswer((_) async {});

      final container = _makeContainer(client);
      addTearDown(container.dispose);
      await container.read(noteProvider.notifier).loadNotes('folder1');

      container.read(selectedNoteIdProvider.notifier).select('n1');
      await container.read(noteProvider.notifier).deleteNote('n1');

      expect(container.read(selectedNoteIdProvider), isNull);
      expect(container.read(noteProvider).notes, isEmpty);
    });

    test('rolls back on API error', () async {
      final client = MockApiClient();
      final notes = [_makeNote('n1')];

      when(() => client.getNotes(folderId: any(named: 'folderId')))
          .thenAnswer((_) async => notes);
      when(() => client.deleteNote(any())).thenThrow(
          const ApiException(500, 'Server error', 'deleteNote'));

      final container = _makeContainer(client);
      addTearDown(container.dispose);
      await container.read(noteProvider.notifier).loadNotes('folder1');

      await container.read(noteProvider.notifier).deleteNote('n1');

      expect(container.read(noteProvider).notes, hasLength(1));
    });
  });

  group('NoteNotifier.moveNote', () {
    test('removes note from current list', () async {
      final client = MockApiClient();
      final notes = [
        _makeNote('n1', folderId: 'folder1'),
        _makeNote('n2', folderId: 'folder1'),
      ];

      when(() => client.getNotes(folderId: any(named: 'folderId')))
          .thenAnswer((_) async => notes);
      when(() => client.updateNote(any(),
          folderId: any(named: 'folderId'))).thenAnswer(
        (_) async => _makeNote('n1', folderId: 'folder2'),
      );

      final container = _makeContainer(client);
      addTearDown(container.dispose);
      await container.read(noteProvider.notifier).loadNotes('folder1');

      await container.read(noteProvider.notifier).moveNote('n1', 'folder2');

      final remaining = container.read(noteProvider).notes.map((n) => n.noteId);
      expect(remaining, isNot(contains('n1')));
      expect(remaining, contains('n2'));
    });

    test('rolls back on API error', () async {
      final client = MockApiClient();
      final notes = [_makeNote('n1', folderId: 'folder1')];

      when(() => client.getNotes(folderId: any(named: 'folderId')))
          .thenAnswer((_) async => notes);
      when(() => client.updateNote(any(),
          folderId: any(named: 'folderId'))).thenThrow(
        const ApiException(500, 'Server error', 'updateNote'),
      );

      final container = _makeContainer(client);
      addTearDown(container.dispose);
      await container.read(noteProvider.notifier).loadNotes('folder1');

      await container.read(noteProvider.notifier).moveNote('n1', 'folder2');

      expect(container.read(noteProvider).notes, hasLength(1));
    });
  });
}
