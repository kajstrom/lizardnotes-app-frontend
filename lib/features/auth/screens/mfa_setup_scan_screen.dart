import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../router/app_router.dart';
import '../../../theme/colour_tokens.dart';
import '../../../theme/dimensions.dart';
import '../../../theme/text_styles.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_shell.dart';

class MfaSetupScanScreen extends ConsumerStatefulWidget {
  const MfaSetupScanScreen({super.key});

  @override
  ConsumerState<MfaSetupScanScreen> createState() => _MfaSetupScanScreenState();
}

class _MfaSetupScanScreenState extends ConsumerState<MfaSetupScanScreen> {
  bool _showSecret = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authProvider.notifier).setupMfa();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final uri = auth.totpSecretUri;
    final secret = _extractSecret(uri);
    final isLoading = auth.status == AuthStatus.loading && uri == null;

    return AuthShell(
      title: 'Set up two-factor auth',
      subtitle:
          'Scan this QR code with an authenticator app — 1Password, Authy, or Google Authenticator.',
      useLockMark: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
            TextButton(
              onPressed: () => setState(() => _showSecret = !_showSecret),
              child: Text(
                _showSecret
                    ? 'Hide setup key'
                    : "Can't scan? Enter setup key manually",
              ),
            ),
            if (_showSecret && secret != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: SelectableText(
                  secret,
                  style: LnTextStyles.codeBlock(color: LnColors.lnText2)
                      .copyWith(letterSpacing: 1.5),
                  textAlign: TextAlign.center,
                ),
              ),
          ] else if (auth.status == AuthStatus.error) ...[
            Text(
              auth.errorMessage ?? 'Failed to load QR code.',
              style: TextStyle(color: LnColors.lnDanger),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => ref.read(authProvider.notifier).setupMfa(),
              child: const Text('Retry'),
            ),
          ],
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: uri != null
                ? () => context.go(RouteNames.mfaSetupVerify)
                : null,
            child: const Text('Next'),
          ),
        ],
      ),
    );
  }

  String? _extractSecret(String? uri) {
    if (uri == null) return null;
    final match = RegExp(r'secret=([^&]+)').firstMatch(uri);
    return match?.group(1);
  }
}

/// Two-dot numbered step indicator shared by [MfaSetupScanScreen] and
/// [MfaSetupVerifyScreen].
///
/// Spec §7.5: two 18 px circles with numbers 1/2, connected by a 28 × 1 px
/// line. Active dot: lnAccentBg fill + lnAccent 1 px border + lnAccent2 text.
/// Inactive dot: lnSurface2 fill + lnBorder2 1 px border + lnText3 text.
class StepIndicator extends StatelessWidget {
  const StepIndicator({super.key, required this.currentStep});

  final int currentStep;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _dot(number: 1, active: currentStep >= 1),
        _line(),
        _dot(number: 2, active: currentStep >= 2),
        const SizedBox(width: 8),
        Text(
          currentStep == 1 ? 'Scan QR code' : 'Verify code',
          style: LnTextStyles.sectionLabel().copyWith(
            textBaseline: TextBaseline.alphabetic,
          ),
        ),
      ],
    );
  }

  Widget _dot({required int number, required bool active}) {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? LnColors.lnAccentBg : LnColors.lnSurface2,
        border: Border.all(
          color: active ? LnColors.lnAccent : LnColors.lnBorder2,
          width: 1,
        ),
      ),
      child: Center(
        child: Text(
          '$number',
          style: LnTextStyles.sectionLabel(
            color: active ? LnColors.lnAccent2 : LnColors.lnText3,
          ).copyWith(fontSize: 9, height: 1.0),
        ),
      ),
    );
  }

  Widget _line() {
    return Container(
      width: 28,
      height: 1,
      color: LnColors.lnBorder2,
    );
  }
}
