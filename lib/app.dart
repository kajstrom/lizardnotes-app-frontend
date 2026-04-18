import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/auth/providers/auth_provider.dart';
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
    ref.listen<AuthState>(authProvider, (_, next) {
      AppRouter.isLoggedIn.value = next.status == AuthStatus.authenticated;
    });

    return MaterialApp.router(
      title: 'LizardNotes',
      theme: AppTheme.dark(),
      routerConfig: AppRouter.router,
    );
  }
}
