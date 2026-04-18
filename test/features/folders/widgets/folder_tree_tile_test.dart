import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lizardnotes_app/api/api_client.dart';
import 'package:lizardnotes_app/features/folders/models/folder.dart';
import 'package:lizardnotes_app/features/folders/providers/folder_provider.dart';
import 'package:lizardnotes_app/features/folders/widgets/folder_tree_tile.dart';
import 'package:mocktail/mocktail.dart';

// ---------------------------------------------------------------------------
// Mock
// ---------------------------------------------------------------------------

class MockApiClient extends Mock implements ApiClient {}

Folder _makeFolder(String id, {String name = 'My Folder', String? parentId}) =>
    Folder(
      folderId: id,
      name: name,
      parentFolderId: parentId,
      path: '/$name',
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
    );

/// Notifier that bypasses the API call and starts idle with given folders.
class _StubbedFolderNotifier extends FolderNotifier {
  @override
  FolderState build() {
    return const FolderState(status: FolderStatus.idle, folders: []);
  }
}

class _StubbedSelectedFolderNotifier extends SelectedFolderNotifier {
  _StubbedSelectedFolderNotifier(this._initial);
  final String? _initial;

  @override
  String? build() => _initial;
}

Widget _wrap({
  required Widget child,
  String? selectedId,
}) {
  return ProviderScope(
    overrides: [
      apiClientProvider.overrideWithValue(MockApiClient()),
      folderProvider.overrideWith(_StubbedFolderNotifier.new),
      if (selectedId != null)
        selectedFolderIdProvider.overrideWith(
          () => _StubbedSelectedFolderNotifier(selectedId),
        ),
    ],
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

/// Simulates a double-tap on the widget at [finder].
Future<void> _doubleTap(WidgetTester tester, Finder finder) async {
  final center = tester.getCenter(finder);
  await tester.tapAt(center);
  await tester.pump(const Duration(milliseconds: 50));
  await tester.tapAt(center);
  await tester.pumpAndSettle();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() {
    registerFallbackValue(_makeFolder('fallback'));
  });

  testWidgets('shows folder name by default', (tester) async {
    final folder = _makeFolder('f1', name: 'Work');
    await tester.pumpWidget(_wrap(child: FolderTreeTile(folder: folder)));
    await tester.pump();

    expect(find.text('Work'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('double-tap activates inline rename', (tester) async {
    final folder = _makeFolder('f1', name: 'Work');
    await tester.pumpWidget(_wrap(child: FolderTreeTile(folder: folder)));
    await tester.pump();

    await _doubleTap(tester, find.text('Work'));

    expect(find.byType(TextField), findsOneWidget);
    final tf = tester.widget<TextField>(find.byType(TextField));
    expect(tf.controller?.text, 'Work');
  });

  testWidgets('Enter commits rename and closes the text field', (tester) async {
    final client = MockApiClient();
    when(() => client.getFolders()).thenAnswer((_) async => []);
    when(() => client.updateFolder(
          any(),
          name: any(named: 'name'),
          parentFolderId: any(named: 'parentFolderId'),
        )).thenAnswer((_) async => _makeFolder('f1', name: 'Renamed'));

    final folder = _makeFolder('f1', name: 'Work');
    await tester.pumpWidget(_wrap(child: FolderTreeTile(folder: folder)));
    await tester.pump();

    await _doubleTap(tester, find.text('Work'));
    expect(find.byType(TextField), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Renamed');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('Escape cancels rename and text field disappears',
      (tester) async {
    final folder = _makeFolder('f1', name: 'Work');
    await tester.pumpWidget(_wrap(child: FolderTreeTile(folder: folder)));
    await tester.pump();

    await _doubleTap(tester, find.text('Work'));
    expect(find.byType(TextField), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Different');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('active tile renders without error', (tester) async {
    final folder = _makeFolder('f1', name: 'Work');
    await tester.pumpWidget(
      _wrap(child: FolderTreeTile(folder: folder), selectedId: 'f1'),
    );
    await tester.pump();

    // Tile renders with the folder name visible.
    expect(find.text('Work'), findsOneWidget);

    // The row should contain the folder icon.
    expect(
      find.byIcon(Icons.folder_outlined),
      findsWidgets,
    );
  });
}
