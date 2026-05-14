import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../router/app_router.dart';
import '../../../theme/colour_tokens.dart';
import '../../../theme/text_styles.dart';
import '../../auth/screens/mfa_setup_scan_screen.dart' show StepIndicator;
import '../../auth/widgets/otp_input_row.dart';
import '../providers/settings_mfa_provider.dart';

class SettingsMfaVerifyScreen extends ConsumerStatefulWidget {
  const SettingsMfaVerifyScreen({super.key});

  @override
  ConsumerState<SettingsMfaVerifyScreen> createState() =>
      _SettingsMfaVerifyScreenState();
}

class _SettingsMfaVerifyScreenState
    extends ConsumerState<SettingsMfaVerifyScreen> {
  String _code = '';

  @override
  Widget build(BuildContext context) {
    ref.listen<SettingsMfaState>(settingsMfaProvider, (_, next) {
      if (next.step == SettingsMfaStep.success) {
        ref.read(settingsMfaProvider.notifier).reset();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Two-factor authentication enabled.'),
            backgroundColor: LnColors.lnSuccess,
          ),
        );
        context.go(RouteNames.appSettings);
      }
    });

    final mfa = ref.watch(settingsMfaProvider);
    final isLoading = mfa.step == SettingsMfaStep.loading;

    return Scaffold(
      backgroundColor: LnColors.lnBg,
      appBar: AppBar(
        backgroundColor: LnColors.lnSurface,
        foregroundColor: LnColors.lnText,
        elevation: 0,
        title: Text(
          'Verify your authenticator',
          style: LnTextStyles.subHeader(),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(RouteNames.appSettingsMfaScan),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Enter the 6-digit code from your authenticator app.',
                    style: LnTextStyles.bodyCompact(color: LnColors.lnText2),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  const StepIndicator(currentStep: 2),
                  const SizedBox(height: 24),
                  if (mfa.errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        mfa.errorMessage!,
                        style: const TextStyle(color: LnColors.lnDanger),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  OtpInputRow(
                    onComplete: (code) => setState(() => _code = code),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: (isLoading || _code.length != 6)
                        ? null
                        : () => ref
                            .read(settingsMfaProvider.notifier)
                            .verifySetup(_code),
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
                    onPressed: () =>
                        context.go(RouteNames.appSettingsMfaScan),
                    child: const Text('Back'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
