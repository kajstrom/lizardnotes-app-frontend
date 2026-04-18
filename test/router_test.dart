import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lizardnotes_app/api/api_client.dart';
import 'package:lizardnotes_app/features/auth/screens/login_screen.dart';
import 'package:lizardnotes_app/features/folders/models/folder.dart';
import 'package:lizardnotes_app/features/folders/screens/folder_list_screen.dart';
import 'package:lizardnotes_app/router/app_router.dart';
import 'package:lizardnotes_app/theme/app_theme.dart';
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

  MockApiClient stubClient() {
    final client = MockApiClient();
    when(() => client.getFolders()).thenAnswer((_) async => []);
    return client;
  }

  group('AppRouter redirects', () {
    testWidgets(
      'unauthenticated access to /app/folders redirects to /login',
      (tester) async {
        final notifier = ValueNotifier<bool>(false);
        final router = AppRouter.buildRouter(notifier);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [apiClientProvider.overrideWithValue(stubClient())],
            child: MaterialApp.router(
              routerConfig: router,
              theme: AppTheme.dark(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        router.go(RouteNames.appFolders);
        await tester.pumpAndSettle();

        expect(find.byType(LoginScreen), findsOneWidget);

        router.dispose();
        notifier.dispose();
      },
    );

    testWidgets(
      'authenticated user navigating to /login is redirected to /app/folders',
      (tester) async {
        // Use a mobile viewport (< 600px) so FolderListScreen is rendered as
        // the shell child rather than being substituted by EditorScreen on desktop.
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final notifier = ValueNotifier<bool>(true);
        final router = AppRouter.buildRouter(notifier);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [apiClientProvider.overrideWithValue(stubClient())],
            child: MaterialApp.router(
              routerConfig: router,
              theme: AppTheme.dark(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        router.go(RouteNames.login);
        await tester.pumpAndSettle();

        expect(find.byType(FolderListScreen), findsOneWidget);

        router.dispose();
        notifier.dispose();
      },
    );
  });
}
