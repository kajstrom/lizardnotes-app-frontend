import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../router/app_router.dart';
import '../../../theme/colour_tokens.dart';
import '../../../theme/dimensions.dart';
import '../../../theme/text_styles.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/settings_mfa_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mfaConfigured = ref.watch(mfaConfiguredProvider);

    return Scaffold(
      backgroundColor: LnColors.lnBg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 20,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _SectionLabel('Security'),
                      const SizedBox(height: 8),
                      _SettingsCard(
                        children: [
                          _MfaRow(
                            mfaConfigured: mfaConfigured,
                            onTap: mfaConfigured.whenOrNull(
                              data: (enabled) => () => context.go(
                                enabled
                                    ? RouteNames.appSettingsMfaManage
                                    : RouteNames.appSettingsMfaScan,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _SectionLabel('Account'),
                      const SizedBox(height: 8),
                      _SettingsCard(
                        children: [
                          _SettingsRow(
                            label: 'Sign out',
                            labelColor: LnColors.lnDanger,
                            onTap: () =>
                                ref.read(authProvider.notifier).signOut(),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: LnColors.lnBorder, width: 1),
        ),
      ),
      child: Text('Settings', style: LnTextStyles.subHeader()),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: LnTextStyles.sectionLabel(color: LnColors.lnText3).copyWith(
        letterSpacing: 0.8,
        fontSize: 10,
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: LnColors.lnSurface,
        borderRadius: BorderRadius.circular(LnDims.r8),
        border: Border.all(color: LnColors.lnBorder2, width: 1),
      ),
      child: Column(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1)
              const Divider(
                height: 1,
                thickness: 1,
                color: LnColors.lnBorder,
                indent: 16,
                endIndent: 16,
              ),
          ],
        ],
      ),
    );
  }
}

class _MfaRow extends StatelessWidget {
  const _MfaRow({required this.mfaConfigured, required this.onTap});
  final AsyncValue<bool> mfaConfigured;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return _SettingsRow(
      label: 'Two-factor authentication',
      trailing: mfaConfigured.when(
        data: (enabled) => _StatusBadge(enabled: enabled),
        loading: () => const SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(strokeWidth: 1.5),
        ),
        error: (e, st) => const SizedBox.shrink(),
      ),
      onTap: onTap,
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.enabled});
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: enabled ? LnColors.lnSuccessBg : LnColors.lnSurface2,
        borderRadius: BorderRadius.circular(LnDims.r4),
        border: Border.all(
          color: enabled ? LnColors.lnSuccessBorder : LnColors.lnBorder2,
          width: 1,
        ),
      ),
      child: Text(
        enabled ? 'Enabled' : 'Not configured',
        style: LnTextStyles.sectionLabel(
          color: enabled ? LnColors.lnSuccess : LnColors.lnText3,
        ).copyWith(fontSize: 11),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.label,
    this.labelColor = LnColors.lnText,
    this.trailing,
    this.onTap,
  });

  final String label;
  final Color labelColor;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(LnDims.r8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Text(label, style: LnTextStyles.bodyCompact(color: labelColor)),
            ),
            if (trailing != null) ...[
              trailing!,
              const SizedBox(width: 8),
            ],
            Icon(
              Icons.chevron_right,
              size: 18,
              color: LnColors.lnText3,
            ),
          ],
        ),
      ),
    );
  }
}
