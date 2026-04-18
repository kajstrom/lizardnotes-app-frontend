import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lizardnotes_app/features/shell/app_shell.dart';
import 'package:lizardnotes_app/features/shell/desktop_shell.dart';
import 'package:lizardnotes_app/features/shell/mobile_shell.dart';

void main() {
  group('AppShell breakpoint switching', () {
    testWidgets('renders MobileShell at 400 px width', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: AppShell(
              location: '/app/folders',
              child: Container(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(MobileShell), findsOneWidget);
      expect(find.byType(DesktopShell), findsNothing);
    });

    testWidgets('renders DesktopShell at 800 px width', (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: AppShell(
              location: '/app/folders',
              child: Container(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DesktopShell), findsOneWidget);
      expect(find.byType(MobileShell), findsNothing);
    });
  });
}
