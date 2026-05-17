import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../router/app_router.dart';
import '../../../theme/colour_tokens.dart';
import '../../../theme/text_styles.dart';
import '../providers/settings_mfa_provider.dart';

class SettingsMfaManageScreen extends ConsumerWidget {
  const SettingsMfaManageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<SettingsMfaState>(settingsMfaProvider, (_, next) {
      if (next.step == SettingsMfaStep.disabled) {
        ref.read(settingsMfaProvider.notifier).reset();
        ref.invalidate(mfaConfiguredProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Two-factor authentication removed.'),
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
          'Two-factor authentication',
          style: LnTextStyles.subHeader(),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(RouteNames.appSettings),
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
                    'Your account is protected by an authenticator app.',
                    style: LnTextStyles.bodyCompact(color: LnColors.lnText2),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  if (mfa.errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        mfa.errorMessage!,
                        style: const TextStyle(color: LnColors.lnDanger),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: LnColors.lnDanger,
                      foregroundColor: LnColors.lnText,
                    ),
                    onPressed: isLoading
                        ? null
                        : () => _confirmRemove(context, ref),
                    child: isLoading
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Remove two-factor authentication'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmRemove(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: LnColors.lnSurface,
        title: Text(
          'Remove two-factor authentication?',
          style: LnTextStyles.subHeader(),
        ),
        content: Text(
          'Removing MFA will make your account less secure. '
          'You can set it up again at any time.',
          style: LnTextStyles.bodyCompact(color: LnColors.lnText2),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: LnColors.lnDanger),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      ref.read(settingsMfaProvider.notifier).disableMfa();
    }
  }
}
