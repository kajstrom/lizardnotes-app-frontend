import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/auth/providers/auth_provider.dart';
import 'features/auth/widgets/restoring_session_splash.dart';
import 'features/notes/providers/selected_note_provider.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

class App extends ConsumerStatefulWidget {
  const App({super.key});

  @override
  ConsumerState<App> createState() => _AppState();
}

class _AppState extends ConsumerState<App> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authProvider.notifier).restoreSession();
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authProvider, (prev, next) {
      AppRouter.isLoggedIn.value = next.status == AuthStatus.authenticated;

      // After a successful session restore, navigate to the previously open
      // note. addPostFrameCallback lets GoRouter's own redirect to /app/folders
      // settle before we push further.
      if (prev?.status == AuthStatus.restoring &&
          next.status == AuthStatus.authenticated) {
        final noteId = ref.read(selectedNoteIdProvider);
        if (noteId != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            AppRouter.router
                .go(RouteNames.appNote.replaceFirst(':noteId', noteId));
          });
        }
      }
    });

    final restoring =
        ref.watch(authProvider.select((s) => s.status == AuthStatus.restoring));

    return MaterialApp.router(
      title: 'LizardNotes',
      theme: AppTheme.dark(),
      routerConfig: AppRouter.router,
      builder: (context, child) {
        if (restoring) return const RestoringSessionSplash();
        return child ?? const SizedBox.shrink();
      },
    );
  }
}
