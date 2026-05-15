import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../router/app_router.dart';
import '../../../theme/colour_tokens.dart';
import '../../../theme/dimensions.dart';
import '../../../theme/text_styles.dart';
import '../../auth/screens/mfa_setup_scan_screen.dart' show StepIndicator;
import '../providers/settings_mfa_provider.dart';

class SettingsMfaScanScreen extends ConsumerStatefulWidget {
  const SettingsMfaScanScreen({super.key});

  @override
  ConsumerState<SettingsMfaScanScreen> createState() =>
      _SettingsMfaScanScreenState();
}

class _SettingsMfaScanScreenState extends ConsumerState<SettingsMfaScanScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final step = ref.read(settingsMfaProvider).step;
      if (step == SettingsMfaStep.idle || step == SettingsMfaStep.error) {
        ref.read(settingsMfaProvider.notifier).startSetup();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final mfa = ref.watch(settingsMfaProvider);
    final uri = mfa.totpSecretUri;
    final secret = _extractSecret(uri);
    final isLoading =
        mfa.step == SettingsMfaStep.loading && uri == null;

    return Scaffold(
      backgroundColor: LnColors.lnBg,
      appBar: AppBar(
        backgroundColor: LnColors.lnSurface,
        foregroundColor: LnColors.lnText,
        elevation: 0,
        title: Text(
          'Set up two-factor auth',
          style: LnTextStyles.subHeader(),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            ref.read(settingsMfaProvider.notifier).reset();
            context.go(RouteNames.appSettings);
          },
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
                    'Scan this QR code with an authenticator app — 1Password, Authy, or Google Authenticator.',
                    style: LnTextStyles.bodyCompact(color: LnColors.lnText2),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  const StepIndicator(currentStep: 1),
                  const SizedBox(height: 24),
                  if (isLoading)
                    const Center(child: CircularProgressIndicator())
                  else if (uri != null) ...[
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(LnDims.r8),
                        ),
                        child: QrImageView(
                          data: uri,
                          version: QrVersions.auto,
                          size: 180,
                          backgroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "Can't scan? Enter this setup key:",
                      style: LnTextStyles.bodyCompact(color: LnColors.lnText2),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    if (secret != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: SelectableText(
                          secret,
                          style: LnTextStyles.codeBlock(color: LnColors.lnText2)
                              .copyWith(letterSpacing: 1.5),
                          textAlign: TextAlign.center,
                        ),
                      ),
                  ] else if (mfa.step == SettingsMfaStep.error) ...[
                    Text(
                      mfa.errorMessage ?? 'Failed to load QR code.',
                      style: const TextStyle(color: LnColors.lnDanger),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () =>
                          ref.read(settingsMfaProvider.notifier).startSetup(),
                      child: const Text('Retry'),
                    ),
                  ],
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: uri != null
                        ? () {
                            ref
                                .read(settingsMfaProvider.notifier)
                                .proceedToVerify();
                            context.go(RouteNames.appSettingsMfaVerify);
                          }
                        : null,
                    child: const Text('Next'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String? _extractSecret(String? uri) {
    if (uri == null) return null;
    final match = RegExp(r'secret=([^&]+)').firstMatch(uri);
    return match?.group(1);
  }
}
