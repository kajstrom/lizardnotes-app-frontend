import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/screens/enter_code_and_password_screen.dart';
import '../features/auth/screens/forgot_password_screen.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/mfa_code_screen.dart';
import '../features/auth/screens/mfa_setup_scan_screen.dart';
import '../features/auth/screens/mfa_setup_verify_screen.dart';
import '../features/auth/screens/set_password_screen.dart';
import '../features/folders/screens/folder_list_screen.dart';
import '../features/notes/screens/editor_screen.dart';
import '../features/notes/screens/note_list_screen.dart';
import '../features/search/screens/search_screen.dart';
import '../features/settings/screens/settings_screen.dart';
import '../features/shell/app_shell.dart';

/// Named route path constants. Use these everywhere instead of string literals.
abstract final class RouteNames {
  static const String login = '/login';
  static const String setPassword = '/login/set-password';
  static const String mfaSetupScan = '/login/mfa-setup/scan';
  static const String mfaSetupVerify = '/login/mfa-setup/verify';
  static const String mfaCode = '/login/mfa-code';
  static const String forgotPassword = '/login/forgot-password';
  static const String forgotPasswordConfirm = '/login/forgot-password/confirm';
  static const String app = '/app';
  static const String appFolders = '/app/folders';
  static const String appFolderNotes = '/app/folders/:folderId';
  static const String appNote = '/app/notes/:noteId';
  static const String appSearch = '/app/search';
  static const String appSettings = '/app/settings';
}

abstract final class AppRouter {
  /// Global login state. Set to `true` after a successful Cognito auth flow,
  /// `false` on sign-out. The router refreshes automatically via
  /// [GoRouter.refreshListenable].
  static final ValueNotifier<bool> isLoggedIn = ValueNotifier<bool>(false);

  /// The singleton router used by [App]. Backed by [isLoggedIn].
  static final GoRouter router = buildRouter(isLoggedIn);

  /// Creates a [GoRouter] driven by [loginNotifier].
  ///
  /// Exposed for testing — pass a local [ValueNotifier] to get an isolated
  /// router instance without touching the global [isLoggedIn].
  static GoRouter buildRouter(ValueNotifier<bool> loginNotifier) {
    return GoRouter(
      initialLocation: RouteNames.login,
      refreshListenable: loginNotifier,
      redirect: (context, state) {
        final location = state.uri.toString();
        final loggedIn = loginNotifier.value;

        // Unauthenticated users must not access /app.
        if (!loggedIn && location.startsWith('/app')) {
          return RouteNames.login;
        }
        // Authenticated users landing exactly on /login go straight to the app.
        if (loggedIn && location == RouteNames.login) {
          return RouteNames.appFolders;
        }
        return null;
      },
      routes: [
        GoRoute(
          path: RouteNames.login,
          builder: (context, state) => const LoginScreen(),
          routes: [
            GoRoute(
              path: 'set-password',
              builder: (context, state) => const SetPasswordScreen(),
            ),
            GoRoute(
              path: 'mfa-setup',
              // /login/mfa-setup itself redirects to the scan step.
              redirect: (context, state) => RouteNames.mfaSetupScan,
              routes: [
                GoRoute(
                  path: 'scan',
                  builder: (context, state) => const MfaSetupScanScreen(),
                ),
                GoRoute(
                  path: 'verify',
                  builder: (context, state) => const MfaSetupVerifyScreen(),
                ),
              ],
            ),
            GoRoute(
              path: 'mfa-code',
              builder: (context, state) => const MfaCodeScreen(),
            ),
            GoRoute(
              path: 'forgot-password',
              builder: (context, state) => const ForgotPasswordScreen(),
              routes: [
                GoRoute(
                  path: 'confirm',
                  builder: (context, state) =>
                      const EnterCodeAndPasswordScreen(),
                ),
              ],
            ),
          ],
        ),
        ShellRoute(
          builder: (context, state, child) => AppShell(
            location: state.uri.toString(),
            child: child,
          ),
          routes: [
            GoRoute(
              path: '/app',
              // /app itself redirects to /app/folders.
              redirect: (context, state) =>
                  state.uri.toString() == '/app' ? RouteNames.appFolders : null,
              routes: [
                GoRoute(
                  path: 'folders',
                  builder: (context, state) => const FolderListScreen(),
                  routes: [
                    GoRoute(
                      path: ':folderId',
                      builder: (context, state) => NoteListScreen(
                        folderId: state.pathParameters['folderId']!,
                      ),
                    ),
                  ],
                ),
                GoRoute(
                  path: 'notes/:noteId',
                  builder: (context, state) => const EditorScreen(),
                ),
                GoRoute(
                  path: 'search',
                  builder: (context, state) => const SearchScreen(),
                ),
                GoRoute(
                  path: 'settings',
                  builder: (context, state) => const SettingsScreen(),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
