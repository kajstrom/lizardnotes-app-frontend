import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../router/app_router.dart';
import '../../../theme/colour_tokens.dart';
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
      title: 'Set up authenticator',
      subtitle: 'Step 1 of 2 — scan the QR code with your authenticator app.',
      useLockMark: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StepIndicator(currentStep: 1),
          const SizedBox(height: 24),
          if (isLoading)
            const Center(child: CircularProgressIndicator())
          else if (uri != null) ...[
            Center(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
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
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    color: LnColors.lnText2,
                    fontSize: 13,
                    letterSpacing: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
          ] else if (auth.status == AuthStatus.error) ...[
            Text(
              auth.errorMessage ?? 'Failed to load QR code.',
              style: const TextStyle(color: Color(0xFFc0524a)),
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

/// Two-dot step indicator shared by [MfaSetupScanScreen] and
/// [MfaSetupVerifyScreen].
class StepIndicator extends StatelessWidget {
  const StepIndicator({super.key, required this.currentStep});

  final int currentStep;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _dot(active: currentStep == 1),
        const SizedBox(width: 8),
        _dot(active: currentStep == 2),
      ],
    );
  }

  Widget _dot({required bool active}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: active ? 24 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: active ? LnColors.lnAccent : LnColors.lnSurface3,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}
