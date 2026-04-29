import 'package:amazon_cognito_identity_dart_2/cognito.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/api_client.dart';
import '../../../router/app_router.dart';
import '../services/auth_service.dart';

enum AuthStatus {
  /// Initial state on app start while we attempt to restore a persisted
  /// session. The router treats this as "not yet decided" — no redirect to
  /// login — and [App] renders a splash overlay.
  restoring,
  unauthenticated,
  loading,
  authenticated,
  requiresNewPassword,
  requiresMfaSetup,
  requiresMfaCode,
  error,
}

class AuthState {
  const AuthState({
    this.status = AuthStatus.unauthenticated,
    this.errorMessage,
    this.session,
    this.totpSecretUri,
    this.pendingEmail,
  });

  final AuthStatus status;
  final String? errorMessage;

  /// The active Cognito session, populated on successful authentication.
  final CognitoUserSession? session;

  /// TOTP URI used to render the QR code on the MFA-setup scan screen.
  final String? totpSecretUri;

  /// Email stored during the forgot-password flow for the confirm step.
  final String? pendingEmail;

  AuthState copyWith({
    AuthStatus? status,
    String? errorMessage,
    CognitoUserSession? session,
    String? totpSecretUri,
    String? pendingEmail,
    bool clearError = false,
    bool clearSession = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      session: clearSession ? null : (session ?? this.session),
      totpSecretUri: totpSecretUri ?? this.totpSecretUri,
      pendingEmail: pendingEmail ?? this.pendingEmail,
    );
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

/// Override this in tests to inject a fake [AuthService].
final authServiceProvider = Provider<AuthService>((_) => CognitoAuthService());

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class AuthNotifier extends Notifier<AuthState> {
  AuthService get _service => ref.read(authServiceProvider);

  @override
  AuthState build() => const AuthState(status: AuthStatus.restoring);

  /// Initiates SRP sign-in. Updates [state.status] based on the Cognito
  /// challenge response.
  Future<void> signIn(String email, String password) async {
    state = state.copyWith(status: AuthStatus.loading, clearError: true);
    try {
      final result = await _service.signIn(email, password);
      state = state.copyWith(
        status: _statusFromResult(result),
        session: _service.currentSession,
      );
      _syncLoginNotifier();
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: _readable(e),
      );
    }
  }

  /// Responds to the NEW_PASSWORD_REQUIRED challenge.
  Future<void> confirmNewPassword(String newPassword) async {
    state = state.copyWith(status: AuthStatus.loading, clearError: true);
    try {
      final result = await _service.confirmNewPassword(newPassword);
      state = state.copyWith(
        status: _statusFromResult(result),
        session: _service.currentSession,
      );
      _syncLoginNotifier();
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: _readable(e),
      );
    }
  }

  /// Calls associateSoftwareToken and stores the TOTP URI in state.
  Future<void> setupMfa() async {
    state = state.copyWith(status: AuthStatus.loading, clearError: true);
    try {
      final uri = await _service.setupMfa();
      state = state.copyWith(
        status: AuthStatus.requiresMfaSetup,
        totpSecretUri: uri,
      );
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: _readable(e),
      );
    }
  }

  /// Verifies the TOTP code entered during MFA setup.
  ///
  /// Transitions to [AuthStatus.authenticated] if a session was obtained,
  /// or [AuthStatus.requiresMfaCode] if re-authentication is needed.
  Future<void> verifyMfaSetup(String code) async {
    state = state.copyWith(status: AuthStatus.loading, clearError: true);
    try {
      await _service.verifyMfaSetup(code);
      final session = _service.currentSession;
      if (session != null) {
        state =
            state.copyWith(status: AuthStatus.authenticated, session: session);
        _syncLoginNotifier();
      } else {
        state = state.copyWith(status: AuthStatus.requiresMfaCode);
      }
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: _readable(e),
      );
    }
  }

  /// Responds to the SOFTWARE_TOKEN_MFA challenge.
  Future<void> confirmMfaCode(String code) async {
    state = state.copyWith(status: AuthStatus.loading, clearError: true);
    try {
      await _service.confirmMfaCode(code);
      state = state.copyWith(
        status: AuthStatus.authenticated,
        session: _service.currentSession,
      );
      _syncLoginNotifier();
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: _readable(e),
      );
    }
  }

  /// Initiates the forgot-password flow, storing [email] for the confirm step.
  Future<void> forgotPassword(String email) async {
    state = state.copyWith(status: AuthStatus.loading, clearError: true);
    try {
      await _service.forgotPassword(email);
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        pendingEmail: email,
      );
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: _readable(e),
      );
    }
  }

  /// Confirms the forgot-password reset with the emailed code.
  Future<void> confirmForgotPassword(
      String email, String code, String newPassword) async {
    state = state.copyWith(status: AuthStatus.loading, clearError: true);
    try {
      await _service.confirmForgotPassword(email, code, newPassword);
      state = const AuthState();
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: _readable(e),
      );
    }
  }

  /// Signs out and clears persisted tokens.
  Future<void> signOut() async {
    await _service.signOut();
    state = const AuthState();
    AppRouter.isLoggedIn.value = false;
  }

  /// Called when an API request discovers the session is no longer valid
  /// (refresh token rejected, or the backend returned 401). Clears persisted
  /// tokens and flips the router back to the login flow.
  Future<void> handleSessionExpired() async {
    if (state.status == AuthStatus.unauthenticated && state.session == null) {
      return;
    }
    await _service.signOut();
    state = const AuthState();
    AppRouter.isLoggedIn.value = false;
  }

  /// Called on app start to restore a persisted session.
  ///
  /// A 10-second timeout protects against Cognito being unreachable — without
  /// it the splash overlay blocks indefinitely. On timeout we fall through to
  /// the login screen; cached tokens stay on disk so the next launch retries.
  Future<void> restoreSession() async {
    bool restored;
    try {
      restored = await _service
          .tryRestoreSession()
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      restored = false;
    }
    if (restored) {
      state = state.copyWith(
        status: AuthStatus.authenticated,
        session: _service.currentSession,
      );
      _syncLoginNotifier();
    } else if (state.status == AuthStatus.restoring) {
      state = state.copyWith(status: AuthStatus.unauthenticated);
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  void _syncLoginNotifier() {
    final loggedIn = state.status == AuthStatus.authenticated;
    AppRouter.isLoggedIn.value = loggedIn;
    if (loggedIn) {
      // Re-arm the API client's expired-handler so a future genuine 401 still
      // routes through handleSessionExpired() (the flag is sticky for the
      // lifetime of the provider otherwise).
      ref.read(apiClientProvider).resetExpiredHandled();
    }
  }

  AuthStatus _statusFromResult(SignInResult result) {
    return switch (result) {
      SignInResult.authenticated => AuthStatus.authenticated,
      SignInResult.requiresNewPassword => AuthStatus.requiresNewPassword,
      SignInResult.requiresMfaSetup => AuthStatus.requiresMfaSetup,
      SignInResult.requiresMfaCode => AuthStatus.requiresMfaCode,
    };
  }

  String _readable(Object e) {
    return e
        .toString()
        .replaceFirst('Exception: ', '')
        .replaceFirst('CognitoClientException: ', '')
        .replaceFirst('CognitoUserException: ', '');
  }
}
