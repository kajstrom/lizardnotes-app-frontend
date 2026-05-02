import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill_test/flutter_quill_test.dart';
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

/// Mirrors the editor-screen layout: a docked format toolbar above a
/// QuillEditor. Used to verify the toolbar does not interfere with
/// keyboard input on the editor.
Widget _wrapWithEditor(QuillController controller, FocusNode editorFocus) {
  return MaterialApp(
    home: Scaffold(
      body: Column(
        children: [
          SizedBox(
            height: 40,
            child: FormatToolbar(
              controller: controller,
              editorFocusNode: editorFocus,
            ),
          ),
          Expanded(
            child: QuillEditor.basic(
              controller: controller,
              focusNode: editorFocus,
            ),
          ),
        ],
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

    testWidgets('H1 applies to current line at collapsed cursor',
        (tester) async {
      final controller = QuillController.basic();
      addTearDown(controller.dispose);

      controller.document.insert(0, 'Hello world');
      controller.updateSelection(
        const TextSelection.collapsed(offset: 2),
        ChangeSource.local,
      );

      await tester.pumpWidget(_wrap(controller));
      await tester.pump();

      await tester.tap(find.text('H1'));
      await tester.pump();

      final h1 = controller.getSelectionStyle().attributes[Attribute.h1.key];
      expect(h1, isNotNull);
    });

    testWidgets('H1 button is highlighted when cursor is on a heading line',
        (tester) async {
      final controller = QuillController.basic();
      addTearDown(controller.dispose);

      controller.document.insert(0, 'Hello world');
      controller.formatText(0, 'Hello world'.length, Attribute.h1);
      controller.updateSelection(
        const TextSelection.collapsed(offset: 3),
        ChangeSource.local,
      );

      await tester.pumpWidget(_wrap(controller));
      await tester.pump();

      final h1Text = tester.widget<Text>(find.text('H1'));
      expect(h1Text.style?.color, LnColors.lnAccent2);
    });

    testWidgets('bullet list toggles for current line at collapsed cursor',
        (tester) async {
      final controller = QuillController.basic();
      addTearDown(controller.dispose);

      controller.document.insert(0, 'Item one');
      controller.updateSelection(
        const TextSelection.collapsed(offset: 4),
        ChangeSource.local,
      );

      await tester.pumpWidget(_wrap(controller));
      await tester.pump();

      await tester.tap(find.text('• list'));
      await tester.pump();

      final ul = controller.getSelectionStyle().attributes[Attribute.ul.key];
      expect(ul, isNotNull);
    });

    testWidgets('bold at collapsed cursor arms toggledStyle for next text',
        (tester) async {
      final controller = QuillController.basic();
      addTearDown(controller.dispose);

      controller.document.insert(0, 'Hello');
      controller.updateSelection(
        const TextSelection.collapsed(offset: 5),
        ChangeSource.local,
      );

      await tester.pumpWidget(_wrap(controller));
      await tester.pump();

      await tester.tap(find.text('B'));
      await tester.pump();

      // toggledStyle is merged into getSelectionStyle for collapsed cursor.
      final bold = controller.getSelectionStyle().attributes[Attribute.bold.key];
      expect(bold, isNotNull);
      expect(controller.toggledStyle.attributes[Attribute.bold.key], isNotNull);
    });

    testWidgets(
        'sibling editor still receives keystrokes while toolbar is mounted',
        (tester) async {
      final controller = QuillController.basic();
      final focus = FocusNode();
      addTearDown(() {
        controller.dispose();
        focus.dispose();
      });

      await tester.pumpWidget(_wrapWithEditor(controller, focus));
      await tester.tap(find.byType(QuillEditor));
      // flutter_quill_test requires the trailing \n to match the implicit
      // document terminator the editor maintains internally.
      await tester.quillEnterText(find.byType(QuillEditor), 'Hello world\n');
      await tester.idle();

      expect(controller.document.toPlainText(), 'Hello world\n');
    });

    testWidgets(
        'editor keeps focus across cursor movement that triggers controller listener',
        (tester) async {
      final controller = QuillController.basic();
      final focus = FocusNode();
      addTearDown(() {
        controller.dispose();
        focus.dispose();
      });

      await tester.pumpWidget(_wrapWithEditor(controller, focus));
      await tester.tap(find.byType(QuillEditor));
      // Type some text — this drives many controller change notifications,
      // each of which the toolbar's listener observes. Before the rebuild
      // filter, this caused the toolbar to setState on every keystroke.
      await tester.quillEnterText(find.byType(QuillEditor), 'abc\n');
      await tester.idle();

      expect(focus.hasFocus, isTrue);
      expect(controller.document.toPlainText(), 'abc\n');

      // Move cursor (collapsed selection update) — must not blow up the
      // rebuild filter or unfocus the editor.
      controller.updateSelection(
        const TextSelection.collapsed(offset: 1),
        ChangeSource.local,
      );
      await tester.pump();

      expect(focus.hasFocus, isTrue);
    });

    testWidgets('saved selection updates even when no visible state changes',
        (tester) async {
      // Even though the toolbar no longer rebuilds on every controller
      // change, the saved selection must still track the live cursor —
      // otherwise applying a format right after typing would target the
      // previous selection.
      final controller = QuillController.basic();
      addTearDown(controller.dispose);

      controller.document.insert(0, 'Hello world');
      await tester.pumpWidget(_wrap(controller));
      await tester.pump();

      // Place collapsed cursor at offset 2 — no visible toolbar state changes
      // (no attribute is active at this position).
      controller.updateSelection(
        const TextSelection.collapsed(offset: 2),
        ChangeSource.local,
      );
      await tester.pump();

      // Now select a range and tap H1 — the toolbar must use the latest
      // selection, not a stale one.
      controller.updateSelection(
        const TextSelection(baseOffset: 0, extentOffset: 5),
        ChangeSource.local,
      );
      await tester.pump();

      await tester.tap(find.text('H1'));
      await tester.pump();

      expect(
        controller.getSelectionStyle().attributes[Attribute.h1.key],
        isNotNull,
      );
    });

    testWidgets('code block toggles for current line at collapsed cursor',
        (tester) async {
      final controller = QuillController.basic();
      addTearDown(controller.dispose);

      controller.document.insert(0, 'print(1)');
      controller.updateSelection(
        const TextSelection.collapsed(offset: 3),
        ChangeSource.local,
      );

      await tester.pumpWidget(_wrap(controller));
      await tester.pump();

      await tester.tap(find.text('code'));
      await tester.pump();

      final codeBlock =
          controller.getSelectionStyle().attributes[Attribute.codeBlock.key];
      expect(codeBlock, isNotNull);
    });

    testWidgets('link button opens dialog when selection is non-collapsed',
        (tester) async {
      final controller = QuillController.basic();
      addTearDown(controller.dispose);

      controller.document.insert(0, 'Hello world');
      controller.updateSelection(
        const TextSelection(baseOffset: 0, extentOffset: 5),
        ChangeSource.local,
      );

      await tester.pumpWidget(_wrap(controller));
      await tester.pump();

      await tester.tap(find.text('link'));
      await tester.pumpAndSettle();

      // Dialog title is rendered.
      expect(find.text('Insert link'), findsOneWidget);
    });

    testWidgets('link button is muted and ignored at collapsed cursor',
        (tester) async {
      final controller = QuillController.basic();
      addTearDown(controller.dispose);

      controller.document.insert(0, 'Hello world');
      controller.updateSelection(
        const TextSelection.collapsed(offset: 2),
        ChangeSource.local,
      );

      await tester.pumpWidget(_wrap(controller));
      await tester.pump();

      // Link text is rendered with muted (lnText3) color when disabled.
      final linkText = tester.widget<Text>(find.text('link'));
      expect(linkText.style?.color, LnColors.lnText3);

      // Tapping does not open the dialog.
      await tester.tap(find.text('link'));
      await tester.pump();
      expect(find.text('Insert link'), findsNothing);
    });
  });
}
