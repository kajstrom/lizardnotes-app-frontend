import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lizardnotes_app/features/notes/models/note.dart';
import 'package:lizardnotes_app/features/notes/widgets/note_tile.dart';
import 'package:lizardnotes_app/theme/colour_tokens.dart';

Note _makeNote({
  String id = 'n1',
  String title = 'Test Note',
  String content = 'Some preview content',
  DateTime? updatedAt,
}) =>
    Note(
      noteId: id,
      folderId: 'folder1',
      title: title,
      content: content,
      createdAt: DateTime(2024),
      updatedAt: updatedAt ?? DateTime.now().subtract(const Duration(hours: 2)),
    );

Widget _wrap(Widget child) =>
    MaterialApp(home: Scaffold(body: child));

void main() {
  group('NoteTile', () {
    testWidgets('renders title and preview text', (tester) async {
      final note = _makeNote(title: 'My Note', content: 'Preview text here');
      await tester.pumpWidget(_wrap(NoteTile(
        note: note,
        isActive: false,
        onTap: () {},
      )));

      expect(find.text('My Note'), findsOneWidget);
      expect(find.text('Preview text here'), findsOneWidget);
    });

    testWidgets('shows relative time', (tester) async {
      final note = _makeNote(
          updatedAt: DateTime.now().subtract(const Duration(hours: 3)));
      await tester.pumpWidget(_wrap(NoteTile(
        note: note,
        isActive: false,
        onTap: () {},
      )));

      expect(find.text('3h ago'), findsOneWidget);
    });

    testWidgets('shows "Untitled" when title is empty', (tester) async {
      final note = _makeNote(title: '');
      await tester.pumpWidget(_wrap(NoteTile(
        note: note,
        isActive: false,
        onTap: () {},
      )));

      expect(find.text('Untitled'), findsOneWidget);
    });

    testWidgets('active tile title uses lnAccent2 color', (tester) async {
      final note = _makeNote(title: 'Active Note');
      await tester.pumpWidget(_wrap(NoteTile(
        note: note,
        isActive: true,
        onTap: () {},
      )));

      final titleWidget = tester.widget<Text>(find.text('Active Note'));
      expect(titleWidget.style?.color, LnColors.lnAccent2);
    });

    testWidgets('inactive tile title uses lnText color', (tester) async {
      final note = _makeNote(title: 'Inactive Note');
      await tester.pumpWidget(_wrap(NoteTile(
        note: note,
        isActive: false,
        onTap: () {},
      )));

      final titleWidget = tester.widget<Text>(find.text('Inactive Note'));
      expect(titleWidget.style?.color, LnColors.lnText);
    });

    testWidgets('calls onTap when tapped', (tester) async {
      var tapped = false;
      final note = _makeNote();
      await tester.pumpWidget(_wrap(NoteTile(
        note: note,
        isActive: false,
        onTap: () => tapped = true,
      )));

      await tester.tap(find.byType(NoteTile));
      expect(tapped, isTrue);
    });

    testWidgets('does not show preview when content is empty', (tester) async {
      final note = _makeNote(content: '');
      await tester.pumpWidget(_wrap(NoteTile(
        note: note,
        isActive: false,
        onTap: () {},
      )));

      // Only title and date visible — no content widget shown.
      expect(find.text(''), findsNothing);
    });
  });
}
