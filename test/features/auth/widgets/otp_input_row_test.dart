import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lizardnotes_app/features/auth/widgets/otp_input_row.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('OtpInputRow', () {
    testWidgets('renders six text fields', (tester) async {
      await tester.pumpWidget(_wrap(OtpInputRow(onComplete: (_) {})));
      expect(find.byType(TextField), findsNWidgets(6));
    });

    testWidgets('auto-advances focus on digit entry', (tester) async {
      await tester.pumpWidget(_wrap(OtpInputRow(onComplete: (_) {})));

      // Tap the first field to focus it.
      await tester.tap(find.byType(TextField).first);
      await tester.pump();

      // Simulate typing '1' into the first field.
      await tester.enterText(find.byType(TextField).first, '1');
      await tester.pump();

      // After entering a digit, focus should have advanced to field[1].
      final secondNode = tester
          .widget<TextField>(find.byType(TextField).at(1))
          .focusNode;
      expect(secondNode?.hasFocus, isTrue);
    });

    testWidgets('onComplete fires with 6-digit string when all fields filled',
        (tester) async {
      String? captured;
      await tester.pumpWidget(
          _wrap(OtpInputRow(onComplete: (c) => captured = c)));

      // Enter each digit one by one. After each digit, focus advances so
      // the next enterText targets the newly-focused field.
      for (var i = 0; i < 6; i++) {
        await tester.enterText(find.byType(TextField).at(i), '$i');
        await tester.pump();
      }

      expect(captured, '012345');
    });

    testWidgets(
        'backspace on empty field while focus is on that field moves focus to previous',
        (tester) async {
      await tester.pumpWidget(_wrap(OtpInputRow(onComplete: (_) {})));

      // Fill the first two fields so we have a realistic state.
      await tester.tap(find.byType(TextField).first);
      await tester.pump();
      await tester.enterText(find.byType(TextField).at(0), '1');
      await tester.pump();
      // Focus is now on field[1].

      // field[1] is empty; send backspace to the currently focused field.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.backspace);
      await tester.pump();

      // Focus should have moved back to field[0].
      final firstNode = tester
          .widget<TextField>(find.byType(TextField).at(0))
          .focusNode;
      expect(firstNode?.hasFocus, isTrue);
    });
  });
}
