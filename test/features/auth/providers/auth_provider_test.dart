import 'package:amazon_cognito_identity_dart_2/cognito.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lizardnotes_app/features/auth/providers/auth_provider.dart';
import 'package:lizardnotes_app/features/auth/services/auth_service.dart';

// ---------------------------------------------------------------------------
// Fake implementation — no real network calls.
// ---------------------------------------------------------------------------

class FakeAuthService implements AuthService {
  SignInResult? _nextSignInResult;
  Object? _nextError;
  final String _totpUri =
      'otpauth://totp/LizardNotes:test@example.com?secret=ABCDEF&issuer=LizardNotes';

  void queueResult(SignInResult r) => _nextSignInResult = r;
  void queueError(Object e) => _nextError = e;

  T _consumeOrThrow<T>(T value) {
    if (_nextError != null) {
      final e = _nextError!;
      _nextError = null;
      throw e;
    }
    _nextSignInResult = null;
    return value;
  }

  @override
  Future<SignInResult> signIn(String email, String password) async =>
      _consumeOrThrow(_nextSignInResult ?? SignInResult.authenticated);

  @override
  Future<SignInResult> confirmNewPassword(String newPassword) async =>
      _consumeOrThrow(_nextSignInResult ?? SignInResult.authenticated);

  @override
  Future<String> setupMfa() async {
    if (_nextError != null) {
      final e = _nextError!;
      _nextError = null;
      throw e;
    }
    return _totpUri;
  }

  @override
  Future<void> verifyMfaSetup(String code) async {
    if (_nextError != null) {
      final e = _nextError!;
      _nextError = null;
      throw e;
    }
  }

  @override
  Future<SignInResult> confirmMfaCode(String code) async =>
      _consumeOrThrow(_nextSignInResult ?? SignInResult.authenticated);

  @override
  Future<void> forgotPassword(String email) async {
    if (_nextError != null) {
      final e = _nextError!;
      _nextError = null;
      throw e;
    }
  }

  @override
  Future<void> confirmForgotPassword(
      String email, String code, String newPassword) async {
    if (_nextError != null) {
      final e = _nextError!;
      _nextError = null;
      throw e;
    }
  }

  @override
  Future<void> signOut() async {}

  @override
  Future<bool> tryRestoreSession() async => false;

  @override
  CognitoUserSession? get currentSession => null;
}

// ---------------------------------------------------------------------------
// Helper
// ---------------------------------------------------------------------------

ProviderContainer _makeContainer(FakeAuthService service) {
  return ProviderContainer(
    overrides: [authServiceProvider.overrideWithValue(service)],
  );
}

void main() {
  group('AuthNotifier.signIn', () {
    test('happy path — transitions to authenticated', () async {
      final svc = FakeAuthService()..queueResult(SignInResult.authenticated);
      final container = _makeContainer(svc);
      addTearDown(container.dispose);

      await container.read(authProvider.notifier).signIn('a@b.com', 'pw');

      expect(container.read(authProvider).status, AuthStatus.authenticated);
      expect(container.read(authProvider).errorMessage, isNull);
    });

    test('NEW_PASSWORD_REQUIRED challenge → requiresNewPassword', () async {
      final svc = FakeAuthService()
        ..queueResult(SignInResult.requiresNewPassword);
      final container = _makeContainer(svc);
      addTearDown(container.dispose);

      await container.read(authProvider.notifier).signIn('a@b.com', 'pw');

      expect(container.read(authProvider).status, AuthStatus.requiresNewPassword);
    });

    test('MFA_SETUP challenge → requiresMfaSetup', () async {
      final svc = FakeAuthService()
        ..queueResult(SignInResult.requiresMfaSetup);
      final container = _makeContainer(svc);
      addTearDown(container.dispose);

      await container.read(authProvider.notifier).signIn('a@b.com', 'pw');

      expect(container.read(authProvider).status, AuthStatus.requiresMfaSetup);
    });

    test('SOFTWARE_TOKEN_MFA challenge → requiresMfaCode', () async {
      final svc = FakeAuthService()
        ..queueResult(SignInResult.requiresMfaCode);
      final container = _makeContainer(svc);
      addTearDown(container.dispose);

      await container.read(authProvider.notifier).signIn('a@b.com', 'pw');

      expect(container.read(authProvider).status, AuthStatus.requiresMfaCode);
    });

    test('error path — transitions to error with message', () async {
      final svc = FakeAuthService()
        ..queueError(Exception('Incorrect username or password.'));
      final container = _makeContainer(svc);
      addTearDown(container.dispose);

      await container.read(authProvider.notifier).signIn('a@b.com', 'bad');

      final state = container.read(authProvider);
      expect(state.status, AuthStatus.error);
      expect(state.errorMessage, contains('Incorrect username or password'));
    });
  });

  group('AuthNotifier.confirmNewPassword', () {
    test('happy path — transitions to authenticated', () async {
      final svc = FakeAuthService()..queueResult(SignInResult.authenticated);
      final container = _makeContainer(svc);
      addTearDown(container.dispose);

      await container
          .read(authProvider.notifier)
          .confirmNewPassword('NewPw123!');

      expect(container.read(authProvider).status, AuthStatus.authenticated);
    });

    test('MFA_SETUP follows → requiresMfaSetup', () async {
      final svc = FakeAuthService()
        ..queueResult(SignInResult.requiresMfaSetup);
      final container = _makeContainer(svc);
      addTearDown(container.dispose);

      await container
          .read(authProvider.notifier)
          .confirmNewPassword('NewPw123!');

      expect(container.read(authProvider).status, AuthStatus.requiresMfaSetup);
    });

    test('error path', () async {
      final svc = FakeAuthService()..queueError(Exception('Invalid session.'));
      final container = _makeContainer(svc);
      addTearDown(container.dispose);

      await container
          .read(authProvider.notifier)
          .confirmNewPassword('NewPw123!');

      expect(container.read(authProvider).status, AuthStatus.error);
    });
  });

  group('AuthNotifier.confirmMfaCode', () {
    test('happy path — transitions to authenticated', () async {
      final svc = FakeAuthService()..queueResult(SignInResult.authenticated);
      final container = _makeContainer(svc);
      addTearDown(container.dispose);

      await container.read(authProvider.notifier).confirmMfaCode('123456');

      expect(container.read(authProvider).status, AuthStatus.authenticated);
    });

    test('wrong code → error', () async {
      final svc = FakeAuthService()
        ..queueError(Exception('Code mismatch exception.'));
      final container = _makeContainer(svc);
      addTearDown(container.dispose);

      await container.read(authProvider.notifier).confirmMfaCode('000000');

      expect(container.read(authProvider).status, AuthStatus.error);
      expect(container.read(authProvider).errorMessage,
          contains('Code mismatch'));
    });
  });

  group('AuthNotifier.setupMfa', () {
    test('populates totpSecretUri in state', () async {
      final svc = FakeAuthService();
      final container = _makeContainer(svc);
      addTearDown(container.dispose);

      await container.read(authProvider.notifier).setupMfa();

      final state = container.read(authProvider);
      expect(state.status, AuthStatus.requiresMfaSetup);
      expect(state.totpSecretUri, startsWith('otpauth://totp/'));
    });
  });

  group('AuthNotifier.signOut', () {
    test('clears state', () async {
      final svc = FakeAuthService()..queueResult(SignInResult.authenticated);
      final container = _makeContainer(svc);
      addTearDown(container.dispose);

      await container.read(authProvider.notifier).signIn('a@b.com', 'pw');
      expect(container.read(authProvider).status, AuthStatus.authenticated);

      await container.read(authProvider.notifier).signOut();
      expect(container.read(authProvider).status, AuthStatus.unauthenticated);
    });
  });
}
