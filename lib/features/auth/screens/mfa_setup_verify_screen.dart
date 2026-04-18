import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../router/app_router.dart';
import '../../../theme/colour_tokens.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_shell.dart';
import '../widgets/otp_input_row.dart';
import 'mfa_setup_scan_screen.dart';

class MfaSetupVerifyScreen extends ConsumerStatefulWidget {
  const MfaSetupVerifyScreen({super.key});

  @override
  ConsumerState<MfaSetupVerifyScreen> createState() =>
      _MfaSetupVerifyScreenState();
}

class _MfaSetupVerifyScreenState extends ConsumerState<MfaSetupVerifyScreen> {
  String _code = '';

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authProvider, (_, next) {
      if (next.status == AuthStatus.authenticated) {
        context.go(RouteNames.appFolders);
      } else if (next.status == AuthStatus.requiresMfaCode) {
        context.go(RouteNames.mfaCode);
      }
    });

    final auth = ref.watch(authProvider);
    final isLoading = auth.status == AuthStatus.loading;

    return AuthShell(
      title: 'Verify your authenticator',
      subtitle: 'Enter the 6-digit code from your authenticator app.',
      useLockMark: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const StepIndicator(currentStep: 2),
          const SizedBox(height: 24),
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
            onComplete: (code) => setState(() => _code = code),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: (isLoading || _code.length != 6) ? null : _submit,
            child: isLoading
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Confirm setup'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => context.go(RouteNames.mfaSetupScan),
            child: const Text('Back'),
          ),
        ],
      ),
    );
  }

  void _submit() {
    ref.read(authProvider.notifier).verifyMfaSetup(_code);
  }
}
