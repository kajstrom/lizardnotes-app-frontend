import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lizardnotes_app/api/api_client.dart';
import 'package:lizardnotes_app/features/folders/models/folder.dart';
import 'package:lizardnotes_app/features/shell/app_shell.dart';
import 'package:lizardnotes_app/features/shell/desktop_shell.dart';
import 'package:lizardnotes_app/features/shell/mobile_shell.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockApiClient extends Mock implements ApiClient {}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  setUpAll(() {
    registerFallbackValue(
      Folder(
        folderId: 'f',
        name: 'F',
        path: '/F',
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
      ),
    );
  });

  Widget buildScope(Size physicalSize, {required Widget child}) {
    final client = MockApiClient();
    when(() => client.getFolders()).thenAnswer((_) async => []);
    return ProviderScope(
      overrides: [apiClientProvider.overrideWithValue(client)],
      child: MaterialApp(home: child),
    );
  }

  group('AppShell breakpoint switching', () {
    testWidgets('renders MobileShell at 400 px width', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        buildScope(
          const Size(400, 800),
          child: AppShell(location: '/app/folders', child: Container()),
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
        buildScope(
          const Size(800, 600),
          child: AppShell(location: '/app/folders', child: Container()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DesktopShell), findsOneWidget);
      expect(find.byType(MobileShell), findsNothing);
    });
  });
}
