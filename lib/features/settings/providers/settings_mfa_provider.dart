import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../../auth/services/auth_service.dart';

enum SettingsMfaStep { idle, loading, scan, verify, success, disabled, error }

class SettingsMfaState {
  const SettingsMfaState({
    this.step = SettingsMfaStep.idle,
    this.totpSecretUri,
    this.errorMessage,
  });

  final SettingsMfaStep step;
  final String? totpSecretUri;
  final String? errorMessage;

  SettingsMfaState copyWith({
    SettingsMfaStep? step,
    String? totpSecretUri,
    String? errorMessage,
    bool clearError = false,
  }) {
    return SettingsMfaState(
      step: step ?? this.step,
      totpSecretUri: totpSecretUri ?? this.totpSecretUri,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

final mfaConfiguredProvider = FutureProvider<bool>((ref) {
  return ref.read(authServiceProvider).isMfaConfigured();
});

final settingsMfaProvider =
    NotifierProvider<SettingsMfaNotifier, SettingsMfaState>(
        SettingsMfaNotifier.new);

class SettingsMfaNotifier extends Notifier<SettingsMfaState> {
  AuthService get _service => ref.read(authServiceProvider);

  @override
  SettingsMfaState build() => const SettingsMfaState();

  /// Calls Cognito to associate a new software token and stores the TOTP URI.
  Future<void> startSetup() async {
    state = state.copyWith(step: SettingsMfaStep.loading, clearError: true);
    try {
      final uri = await _service.setupMfa();
      state = state.copyWith(step: SettingsMfaStep.scan, totpSecretUri: uri);
    } catch (e) {
      state = state.copyWith(
        step: SettingsMfaStep.error,
        errorMessage: _readable(e),
      );
    }
  }

  /// Advances from scan to verify step without re-fetching the URI.
  void proceedToVerify() {
    state = state.copyWith(step: SettingsMfaStep.verify, clearError: true);
  }

  /// Verifies the OTP code and marks MFA as configured on success.
  Future<void> verifySetup(String code) async {
    state = state.copyWith(step: SettingsMfaStep.loading, clearError: true);
    try {
      await _service.verifyMfaSetup(code);
      state = state.copyWith(step: SettingsMfaStep.success);
    } catch (e) {
      state = state.copyWith(
        step: SettingsMfaStep.verify,
        errorMessage: _readable(e),
      );
    }
  }

  Future<void> disableMfa() async {
    state = state.copyWith(step: SettingsMfaStep.loading, clearError: true);
    try {
      await _service.disableMfa();
      state = state.copyWith(step: SettingsMfaStep.disabled);
    } catch (e) {
      state = state.copyWith(
        step: SettingsMfaStep.error,
        errorMessage: _readable(e),
      );
    }
  }

  void reset() => state = const SettingsMfaState();

  String _readable(Object e) => e
      .toString()
      .replaceFirst('Exception: ', '')
      .replaceFirst('CognitoClientException: ', '')
      .replaceFirst('CognitoUserException: ', '');
}
