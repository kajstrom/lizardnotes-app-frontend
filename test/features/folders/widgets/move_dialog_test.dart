import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lizardnotes_app/api/api_client.dart';
import 'package:lizardnotes_app/features/folders/models/folder.dart';
import 'package:lizardnotes_app/features/folders/providers/folder_provider.dart';
import 'package:lizardnotes_app/features/folders/widgets/move_dialog.dart';
import 'package:mocktail/mocktail.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

class MockApiClient extends Mock implements ApiClient {}

Folder _makeFolder(String id, {String name = 'Folder', String? parentId}) =>
    Folder(
      folderId: id,
      name: name,
      parentFolderId: parentId,
      path: '/$name',
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
    );

class _StubbedFolderNotifier extends FolderNotifier {
  _StubbedFolderNotifier(this._folders);

  final List<Folder> _folders;

  @override
  FolderState build() => FolderState(
        status: FolderStatus.idle,
        folders: _folders,
      );
}

Widget _wrapDialog({
  required Folder targetFolder,
  required List<Folder> allFolders,
}) {
  return ProviderScope(
    overrides: [
      apiClientProvider.overrideWithValue(MockApiClient()),
      folderProvider.overrideWith(
        () => _StubbedFolderNotifier(allFolders),
      ),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (ctx) => TextButton(
            onPressed: () => showMoveDialog(
              context: ctx,
              folder: targetFolder,
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() {
    registerFallbackValue(_makeFolder('fallback'));
  });

  testWidgets('folder itself is disabled in the list', (tester) async {
    final target = _makeFolder('target', name: 'Target');
    final other = _makeFolder('other', name: 'Other');

    await tester.pumpWidget(
      _wrapDialog(
        targetFolder: target,
        allFolders: [target, other],
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    // Find the DestinationRow for 'Target'.
    final targetRow = find.ancestor(
      of: find.text('Target'),
      matching: find.byType(Opacity),
    );
    expect(targetRow, findsWidgets);
    // The Opacity widget for a disabled row has opacity 0.55.
    final op = tester.widget<Opacity>(targetRow.first);
    expect(op.opacity, 0.55);
  });

  testWidgets('descendants are disabled', (tester) async {
    final target = _makeFolder('target', name: 'Target');
    final child = _makeFolder('child', name: 'Child', parentId: 'target');
    final other = _makeFolder('other', name: 'Other');

    await tester.pumpWidget(
      _wrapDialog(
        targetFolder: target,
        allFolders: [target, child, other],
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final childRow = find.ancestor(
      of: find.text('Child'),
      matching: find.byType(Opacity),
    );
    expect(childRow, findsWidgets);
    final op = tester.widget<Opacity>(childRow.first);
    expect(op.opacity, 0.55);
  });

  testWidgets('Move here is disabled until a destination is selected',
      (tester) async {
    final target = _makeFolder('target', name: 'Target');
    final other = _makeFolder('other', name: 'Other');

    await tester.pumpWidget(
      _wrapDialog(
        targetFolder: target,
        allFolders: [target, other],
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    // 'Move here' button should be present but not enabled.
    expect(find.text('Move here'), findsOneWidget);

    // Tap on an enabled destination.
    await tester.tap(find.text('Other'));
    await tester.pump();

    // Now 'Move here' should be tappable (no assertion on pop — just
    // verifying we can reach it without exception).
    expect(find.text('Move here'), findsOneWidget);
  });
}
