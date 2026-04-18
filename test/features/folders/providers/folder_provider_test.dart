import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lizardnotes_app/api/api_client.dart';
import 'package:lizardnotes_app/features/folders/models/folder.dart';
import 'package:lizardnotes_app/features/folders/providers/folder_provider.dart';
import 'package:mocktail/mocktail.dart';

// ---------------------------------------------------------------------------
// Mock
// ---------------------------------------------------------------------------

class MockApiClient extends Mock implements ApiClient {}

Folder _makeFolder(
  String id, {
  String name = 'Folder',
  String? parentId,
}) =>
    Folder(
      folderId: id,
      name: name,
      parentFolderId: parentId,
      path: '/$name',
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
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
    // Register fallback values for Mocktail
    registerFallbackValue(_makeFolder('fallback'));
  });

  group('FolderNotifier.loadFolders', () {
    test('populates folders in state on success', () async {
      final client = MockApiClient();
      final folders = [
        _makeFolder('f1', name: 'Work'),
        _makeFolder('f2', name: 'Personal'),
      ];
      when(() => client.getFolders()).thenAnswer((_) async => folders);

      final container = _makeContainer(client);
      addTearDown(container.dispose);

      // Trigger the auto-load.
      await container.read(folderProvider.notifier).loadFolders();

      final state = container.read(folderProvider);
      expect(state.status, FolderStatus.idle);
      expect(state.folders, hasLength(2));
      expect(state.folders.map((f) => f.folderId),
          containsAll(['f1', 'f2']));
      expect(state.errorMessage, isNull);
    });

    test('transitions to error when API throws', () async {
      final client = MockApiClient();
      when(() => client.getFolders())
          .thenThrow(const ApiException(500, 'Internal error', 'getFolders'));

      final container = _makeContainer(client);
      addTearDown(container.dispose);

      await container.read(folderProvider.notifier).loadFolders();

      final state = container.read(folderProvider);
      expect(state.status, FolderStatus.error);
      expect(state.errorMessage, isNotNull);
    });
  });

  group('FolderNotifier.createFolder', () {
    test('optimistic update adds folder before API completes', () async {
      final client = MockApiClient();
      final created = _makeFolder('real-1', name: 'Work');
      // Use a Completer so we can inspect the optimistic state before the
      // API mock resolves.
      final apiCompleter = Completer<Folder>();

      when(() => client.getFolders()).thenAnswer((_) async => []);
      when(
        () => client.createFolder(
          name: any(named: 'name'),
          parentFolderId: any(named: 'parentFolderId'),
        ),
      ).thenAnswer((_) => apiCompleter.future);

      final container = _makeContainer(client);
      addTearDown(container.dispose);
      await container.read(folderProvider.notifier).loadFolders();

      // Start createFolder — API call is blocked by the Completer.
      final future =
          container.read(folderProvider.notifier).createFolder('Work');

      // Optimistic entry is added synchronously before the first await.
      final optimistic = container.read(folderProvider).folders;
      expect(optimistic, isNotEmpty);
      expect(optimistic.any((f) => f.folderId.startsWith('temp_')), isTrue);

      // Unblock the API mock and wait for completion.
      apiCompleter.complete(created);
      await future;

      // Real folder has replaced the temp entry.
      final finalState = container.read(folderProvider);
      expect(finalState.folders.any((f) => f.folderId == 'real-1'), isTrue);
      expect(
        finalState.folders.any((f) => f.folderId.startsWith('temp_')),
        isFalse,
      );
    });

    test('rolls back on API error', () async {
      final client = MockApiClient();

      when(() => client.getFolders()).thenAnswer((_) async => []);
      when(() => client.createFolder(name: any(named: 'name'),
              parentFolderId: any(named: 'parentFolderId')))
          .thenThrow(
              const ApiException(500, 'Server error', 'createFolder'));

      final container = _makeContainer(client);
      addTearDown(container.dispose);
      await container.read(folderProvider.notifier).loadFolders();

      await container
          .read(folderProvider.notifier)
          .createFolder('Work');

      // State rolled back — no folders.
      expect(container.read(folderProvider).folders, isEmpty);
    });
  });

  group('FolderNotifier.deleteFolder', () {
    test('removes folder and all descendants from state', () async {
      final client = MockApiClient();
      final folders = [
        _makeFolder('root', name: 'Root'),
        _makeFolder('child1', name: 'Child1', parentId: 'root'),
        _makeFolder('child2', name: 'Child2', parentId: 'root'),
        _makeFolder('grandchild', name: 'GrandChild', parentId: 'child1'),
        _makeFolder('other', name: 'Other'),
      ];

      when(() => client.getFolders()).thenAnswer((_) async => folders);
      when(() => client.deleteFolder(any()))
          .thenAnswer((_) async {});

      final container = _makeContainer(client);
      addTearDown(container.dispose);
      await container.read(folderProvider.notifier).loadFolders();

      await container
          .read(folderProvider.notifier)
          .deleteFolder('root');

      final remaining =
          container.read(folderProvider).folders.map((f) => f.folderId);
      expect(remaining, equals(['other']));
    });

    test('rolls back on API error', () async {
      final client = MockApiClient();
      final folders = [_makeFolder('f1', name: 'Folder')];

      when(() => client.getFolders()).thenAnswer((_) async => folders);
      when(() => client.deleteFolder(any())).thenThrow(
          const ApiException(500, 'Server error', 'deleteFolder'));

      final container = _makeContainer(client);
      addTearDown(container.dispose);
      await container.read(folderProvider.notifier).loadFolders();

      await container.read(folderProvider.notifier).deleteFolder('f1');

      expect(container.read(folderProvider).folders, hasLength(1));
    });
  });

  group('FolderNotifier.childrenOf', () {
    test('returns root folders when parentFolderId is null', () async {
      final client = MockApiClient();
      final folders = [
        _makeFolder('root1'),
        _makeFolder('root2'),
        _makeFolder('child', parentId: 'root1'),
      ];
      when(() => client.getFolders()).thenAnswer((_) async => folders);

      final container = _makeContainer(client);
      addTearDown(container.dispose);
      await container.read(folderProvider.notifier).loadFolders();

      final roots =
          container.read(folderProvider.notifier).childrenOf(null);
      expect(roots.map((f) => f.folderId), containsAll(['root1', 'root2']));
      expect(roots.any((f) => f.folderId == 'child'), isFalse);
    });

    test('returns direct children for a given parentFolderId', () async {
      final client = MockApiClient();
      final folders = [
        _makeFolder('root'),
        _makeFolder('child1', parentId: 'root'),
        _makeFolder('child2', parentId: 'root'),
        _makeFolder('grandchild', parentId: 'child1'),
      ];
      when(() => client.getFolders()).thenAnswer((_) async => folders);

      final container = _makeContainer(client);
      addTearDown(container.dispose);
      await container.read(folderProvider.notifier).loadFolders();

      final children =
          container.read(folderProvider.notifier).childrenOf('root');
      expect(
          children.map((f) => f.folderId),
          containsAll(['child1', 'child2']));
      expect(children.any((f) => f.folderId == 'grandchild'), isFalse);
    });
  });
}
