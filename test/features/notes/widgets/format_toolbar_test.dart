import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lizardnotes_app/features/notes/widgets/format_toolbar.dart';
import 'package:lizardnotes_app/theme/colour_tokens.dart';

Widget _wrap(QuillController controller) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        height: 40,
        child: FormatToolbar(controller: controller),
      ),
    ),
  );
}

void main() {
  group('FormatToolbar', () {
    testWidgets('renders all expected buttons', (tester) async {
      final controller = QuillController.basic();
      addTearDown(controller.dispose);

      await tester.pumpWidget(_wrap(controller));

      expect(find.text('B'), findsOneWidget);
      expect(find.text('I'), findsOneWidget);
      expect(find.text('H1'), findsOneWidget);
      expect(find.text('H2'), findsOneWidget);
      expect(find.text('H3'), findsOneWidget);
      expect(find.text('• list'), findsOneWidget);
      expect(find.text('1. list'), findsOneWidget);
      expect(find.text('code'), findsOneWidget);
      expect(find.text('link'), findsOneWidget);
    });

    testWidgets('bold button toggles bold format at cursor', (tester) async {
      final controller = QuillController.basic();
      addTearDown(controller.dispose);

      // Insert some text and select it.
      controller.document.insert(0, 'Hello world');
      controller.updateSelection(
        const TextSelection(baseOffset: 0, extentOffset: 5),
        ChangeSource.local,
      );

      await tester.pumpWidget(_wrap(controller));
      await tester.pump();

      // Bold is not active initially.
      final boldBefore =
          controller.getSelectionStyle().attributes[Attribute.bold.key];
      expect(boldBefore, isNull);

      // Tap the B button.
      await tester.tap(find.text('B'));
      await tester.pump();

      // Bold should now be applied.
      final boldAfter =
          controller.getSelectionStyle().attributes[Attribute.bold.key];
      expect(boldAfter, isNotNull);
    });

    testWidgets('bold button toggles bold off when already bold', (tester) async {
      final controller = QuillController.basic();
      addTearDown(controller.dispose);

      controller.document.insert(0, 'Hello world');
      controller.updateSelection(
        const TextSelection(baseOffset: 0, extentOffset: 5),
        ChangeSource.local,
      );

      await tester.pumpWidget(_wrap(controller));
      await tester.pump();

      // Apply bold.
      await tester.tap(find.text('B'));
      await tester.pump();
      expect(
        controller.getSelectionStyle().attributes[Attribute.bold.key],
        isNotNull,
      );

      // Remove bold.
      await tester.tap(find.text('B'));
      await tester.pump();
      final boldRemoved =
          controller.getSelectionStyle().attributes[Attribute.bold.key];
      expect(boldRemoved, isNull);
    });

    testWidgets('active state color when cursor is in bold text', (tester) async {
      final controller = QuillController.basic();
      addTearDown(controller.dispose);

      controller.document.insert(0, 'Hello world');
      controller.updateSelection(
        const TextSelection(baseOffset: 0, extentOffset: 5),
        ChangeSource.local,
      );
      controller.formatSelection(Attribute.bold);

      // Move selection to inside the bold text (collapsed cursor).
      controller.updateSelection(
        const TextSelection.collapsed(offset: 2),
        ChangeSource.local,
      );

      await tester.pumpWidget(_wrap(controller));
      await tester.pump();

      // The bold button's text should use lnAccent2 color when active.
      // Find the 'B' text widget and check its style.
      final boldTextWidget = tester.widget<Text>(find.text('B'));
      expect(boldTextWidget.style?.color, LnColors.lnAccent2);
    });

    testWidgets('italic button applies italic format', (tester) async {
      final controller = QuillController.basic();
      addTearDown(controller.dispose);

      controller.document.insert(0, 'Hello world');
      controller.updateSelection(
        const TextSelection(baseOffset: 0, extentOffset: 5),
        ChangeSource.local,
      );

      await tester.pumpWidget(_wrap(controller));
      await tester.pump();

      await tester.tap(find.text('I'));
      await tester.pump();

      final italicAttr =
          controller.getSelectionStyle().attributes[Attribute.italic.key];
      expect(italicAttr, isNotNull);
    });
  });
}
