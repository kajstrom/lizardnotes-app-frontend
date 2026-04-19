import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lizardnotes_app/features/folders/models/folder.dart';
import 'package:lizardnotes_app/features/folders/providers/folder_provider.dart';
import 'package:lizardnotes_app/features/notes/models/note.dart';
import 'package:lizardnotes_app/features/notes/providers/note_provider.dart';
import 'package:lizardnotes_app/features/search/providers/search_provider.dart';
import 'package:lizardnotes_app/features/search/widgets/note_result_row.dart';
import 'package:lizardnotes_app/features/search/widgets/search_modal.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Note _note(String id, {String title = 'Note', String folderId = 'f1'}) => Note(
      noteId: id,
      folderId: folderId,
      title: title,
      content: '',
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
    );

Folder _makeFolder(String id) => Folder(
      folderId: id,
      name: 'Folder',
      path: 'Folder',
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
    );

// Fake notifiers that serve fixed data.
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

// SearchNotifier with pre-populated results and no debounce timer (prevents
// pending-timer assertions at test teardown).
class _FakeSearchNotifier extends SearchNotifier {
  _FakeSearchNotifier(this._initial);
  final SearchState _initial;

  @override
  SearchState build() {
    ref.onDispose(() {});
    return _initial;
  }

  @override
  void setQuery(String q) {
    // Immediate update — no Timer — keeps tests deterministic.
    state = state.copyWith(query: q);
  }
}

/// Opens a dialog containing [SearchModal] and returns a widget tree suitable
/// for keyboard and state testing.
///
/// The outer widget is [MaterialApp] so that [showDialog] gets the correct
/// Localizations ancestor.
Widget _app(List<Note> notes) {
  final noteResults = notes
      .map((n) => NoteSearchResult(
            note: n,
            titleMatchRanges: const [],
            folderPath: 'Root',
          ))
      .toList();

  final initialState = SearchState(
    query: 'test',
    isOpen: true,
    results: SearchResults(notes: noteResults),
  );

  return ProviderScope(
    overrides: [
      noteProvider.overrideWith(() => _FakeNoteNotifier(notes)),
      folderProvider.overrideWith(
        () => _FakeFolderNotifier(
          notes.map((n) => _makeFolder(n.folderId)).toList(),
        ),
      ),
      searchProvider.overrideWith(
        () => _FakeSearchNotifier(initialState),
      ),
    ],
    child: const MaterialApp(
      // A Scaffold as the home so that showDialog has the right context.
      home: _TestHome(),
    ),
  );
}

/// Home widget that immediately shows [SearchModal] as a dialog on first build.
class _TestHome extends StatefulWidget {
  const _TestHome();
  @override
  State<_TestHome> createState() => _TestHomeState();
}

class _TestHomeState extends State<_TestHome> {
  bool _shown = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_shown) {
      _shown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showDialog<void>(
          context: context,
          barrierDismissible: true,
          builder: (_) => const SearchModal(),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) => const Scaffold(body: SizedBox.shrink());
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('SearchModal keyboard navigation', () {
    testWidgets('ArrowDown twice moves cursor to second result', (tester) async {
      final notes = [
        _note('n1', title: 'First note'),
        _note('n2', title: 'Second note'),
        _note('n3', title: 'Third note'),
      ];
      await tester.pumpWidget(_app(notes));
      // Let post-frame callback fire so the dialog appears.
      await tester.pumpAndSettle();

      expect(find.byType(SearchModal), findsOneWidget);

      // First ArrowDown → cursor index 0.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      // Second ArrowDown → cursor index 1.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();

      final rows = tester.widgetList<NoteResultRow>(find.byType(NoteResultRow));
      final activeRows = rows.where((r) => r.isActive).toList();
      expect(activeRows, hasLength(1));
      expect(activeRows[0].result.note.noteId, 'n2');
    });

    testWidgets('Escape closes the modal', (tester) async {
      final notes = [_note('n1', title: 'Note')];
      await tester.pumpWidget(_app(notes));
      await tester.pumpAndSettle();

      expect(find.byType(SearchModal), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.byType(SearchModal), findsNothing);
    });

    testWidgets('cursor resets to −1 when query changes', (tester) async {
      final notes = [
        _note('n1', title: 'First note'),
        _note('n2', title: 'Second note'),
      ];
      await tester.pumpWidget(_app(notes));
      await tester.pumpAndSettle();

      // Move cursor to row 0.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();

      var rows = tester.widgetList<NoteResultRow>(find.byType(NoteResultRow));
      expect(rows.any((r) => r.isActive), isTrue);

      // Change the query — should reset cursor.
      await tester.enterText(find.byType(TextField).first, 'changed');
      await tester.pump();

      rows = tester.widgetList<NoteResultRow>(find.byType(NoteResultRow));
      expect(rows.every((r) => !r.isActive), isTrue);
    });
  });
}
