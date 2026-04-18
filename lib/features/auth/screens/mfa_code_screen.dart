import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../router/app_router.dart';
import '../../../theme/colour_tokens.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_info_box.dart';
import '../widgets/auth_shell.dart';
import '../widgets/otp_input_row.dart';

class MfaCodeScreen extends ConsumerStatefulWidget {
  const MfaCodeScreen({super.key});

  @override
  ConsumerState<MfaCodeScreen> createState() => _MfaCodeScreenState();
}

class _MfaCodeScreenState extends ConsumerState<MfaCodeScreen> {
  String _code = '';

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authProvider, (_, next) {
      if (next.status == AuthStatus.authenticated) {
        context.go(RouteNames.appFolders);
      }
    });

    final auth = ref.watch(authProvider);
    final isLoading = auth.status == AuthStatus.loading;
    final email = auth.pendingEmail ?? '';

    return AuthShell(
      title: 'Enter verification code',
      subtitle: 'Open your authenticator app and enter the 6-digit code.',
      useLockMark: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (email.isNotEmpty)
            AuthInfoBox(
              variant: AuthInfoBoxVariant.neutral,
              message: 'Signing in as $email',
            ),
          const SizedBox(height: 16),
          if (auth.status == AuthStatus.error && auth.errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                auth.errorMessage!,
                style: const TextStyle(color: LnColors.lnDanger),
                textAlign: TextAlign.center,
              ),
            ),
          OtpInputRow(
            onComplete: (code) {
              setState(() => _code = code);
              _submit(code);
            },
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: (isLoading || _code.length != 6)
                ? null
                : () => _submit(_code),
            child: isLoading
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Verify'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: isLoading
                ? null
                : () async {
                    await ref.read(authProvider.notifier).signOut();
                    if (context.mounted) context.go(RouteNames.login);
                  },
            child: const Text('Use a different account'),
          ),
        ],
      ),
    );
  }

  void _submit(String code) {
    if (code.length != 6) return;
    ref.read(authProvider.notifier).confirmMfaCode(code);
  }
}
