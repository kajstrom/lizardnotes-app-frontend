import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lizardnotes_app/features/auth/widgets/auth_info_box.dart';
import 'package:lizardnotes_app/theme/colour_tokens.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('AuthInfoBox', () {
    testWidgets('amber variant renders message text', (tester) async {
      await tester.pumpWidget(_wrap(const AuthInfoBox(
        message: 'Temporary password notice',
        variant: AuthInfoBoxVariant.amber,
      )));

      expect(find.text('Temporary password notice'), findsOneWidget);
    });

    testWidgets('amber variant uses amber foreground colour', (tester) async {
      await tester.pumpWidget(_wrap(const AuthInfoBox(
        message: 'Warning',
        variant: AuthInfoBoxVariant.amber,
      )));

      final textWidget = tester.widget<Text>(find.text('Warning'));
      expect(textWidget.style?.color, LnColors.lnAmber);
    });

    testWidgets('green variant renders message text', (tester) async {
      await tester.pumpWidget(_wrap(const AuthInfoBox(
        message: 'Code sent to your email',
        variant: AuthInfoBoxVariant.green,
      )));

      expect(find.text('Code sent to your email'), findsOneWidget);
    });

    testWidgets('green variant uses success foreground colour', (tester) async {
      await tester.pumpWidget(_wrap(const AuthInfoBox(
        message: 'Success',
        variant: AuthInfoBoxVariant.green,
      )));

      final textWidget = tester.widget<Text>(find.text('Success'));
      expect(textWidget.style?.color, LnColors.lnSuccess);
    });

    testWidgets('amber container has amber border colour', (tester) async {
      await tester.pumpWidget(_wrap(const AuthInfoBox(
        message: 'Warning',
        variant: AuthInfoBoxVariant.amber,
      )));

      final container = tester.widget<Container>(find.byType(Container).first);
      final decoration = container.decoration as BoxDecoration;
      final border = decoration.border as Border;
      expect(border.top.color, LnColors.lnAmber);
    });

    testWidgets('green container has success border colour', (tester) async {
      await tester.pumpWidget(_wrap(const AuthInfoBox(
        message: 'Success',
        variant: AuthInfoBoxVariant.green,
      )));

      final container = tester.widget<Container>(find.byType(Container).first);
      final decoration = container.decoration as BoxDecoration;
      final border = decoration.border as Border;
      expect(border.top.color, LnColors.lnSuccess);
    });
  });
}
