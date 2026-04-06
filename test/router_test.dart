import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lizardnotes_app/features/auth/screens/login_screen.dart';
import 'package:lizardnotes_app/features/folders/screens/folder_list_screen.dart';
import 'package:lizardnotes_app/router/app_router.dart';
import 'package:lizardnotes_app/theme/app_theme.dart';

void main() {
  group('AppRouter redirects', () {
    testWidgets(
      'unauthenticated access to /app/folders redirects to /login',
      (tester) async {
        final notifier = ValueNotifier<bool>(false);
        final router = AppRouter.buildRouter(notifier);

        await tester.pumpWidget(
          MaterialApp.router(
            routerConfig: router,
            theme: AppTheme.dark(),
          ),
        );
        await tester.pumpAndSettle();

        // Navigate to a protected route.
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
        final notifier = ValueNotifier<bool>(true);
        final router = AppRouter.buildRouter(notifier);

        await tester.pumpWidget(
          MaterialApp.router(
            routerConfig: router,
            theme: AppTheme.dark(),
          ),
        );
        await tester.pumpAndSettle();

        // Explicitly navigate to /login — redirect should fire.
        router.go(RouteNames.login);
        await tester.pumpAndSettle();

        expect(find.byType(FolderListScreen), findsOneWidget);

        router.dispose();
        notifier.dispose();
      },
    );
  });
}
