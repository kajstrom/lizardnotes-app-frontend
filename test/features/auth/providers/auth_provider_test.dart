import 'package:amazon_cognito_identity_dart_2/cognito.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lizardnotes_app/features/auth/providers/auth_provider.dart';
import 'package:lizardnotes_app/features/auth/services/auth_service.dart';
import 'package:lizardnotes_app/features/notes/providers/selected_note_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Fake implementation — no real network calls.
// ---------------------------------------------------------------------------

class FakeAuthService implements AuthService {
  SignInResult? _nextSignInResult;
  Object? _nextError;
  Object? _restoreError;
  bool _restoreReturns = false;
  final String _totpUri =
      'otpauth://totp/LizardNotes:test@example.com?secret=ABCDEF&issuer=LizardNotes';

  void queueResult(SignInResult r) => _nextSignInResult = r;
  void queueError(Object e) => _nextError = e;
  void queueRestoreError(Object e) => _restoreError = e;
  void queueRestoreSuccess() => _restoreReturns = true;

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
  Future<bool> tryRestoreSession() async {
    if (_restoreError != null) {
      final e = _restoreError!;
      _restoreError = null;
      throw e;
    }
    return _restoreReturns;
  }

  @override
  Future<String?> getValidAccessToken() async => null;

  @override
  Future<String?> forceRefresh() async => null;

  @override
  CognitoUserSession? get currentSession => null;

  @override
  Future<bool> isMfaConfigured() async => false;

  @override
  Future<void> markMfaConfigured() async {}

  @override
  Future<void> clearMfaConfigured() async {}

  @override
  Future<void> disableMfa() async {}
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
  setUpAll(TestWidgetsFlutterBinding.ensureInitialized);
  setUp(() => SharedPreferences.setMockInitialValues({}));

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

  group('AuthNotifier.restoreSession', () {
    test('restore failure clears restoring state', () async {
      final svc = FakeAuthService(); // tryRestoreSession returns false
      final container = _makeContainer(svc);
      addTearDown(container.dispose);

      await container.read(authProvider.notifier).restoreSession();

      expect(container.read(authProvider).status, AuthStatus.unauthenticated);
    });

    test('restore exception is caught — falls through to unauthenticated',
        () async {
      // Mirrors the Cognito-unreachable case: tryRestoreSession throws (or
      // times out). The notifier should not stay stuck in `restoring`.
      final svc = FakeAuthService()
        ..queueRestoreError(Exception('network unreachable'));
      final container = _makeContainer(svc);
      addTearDown(container.dispose);

      await container.read(authProvider.notifier).restoreSession();

      expect(container.read(authProvider).status, AuthStatus.unauthenticated);
    });

    test('restore success sets authenticated and restores persisted note',
        () async {
      SharedPreferences.setMockInitialValues(
          {'lastSelectedNoteId': 'note-xyz'});
      final svc = FakeAuthService()..queueRestoreSuccess();
      final container = _makeContainer(svc);
      addTearDown(container.dispose);

      await container.read(authProvider.notifier).restoreSession();

      expect(container.read(authProvider).status, AuthStatus.authenticated);
      expect(container.read(selectedNoteIdProvider), 'note-xyz');
    });
  });

  group('AuthNotifier.signOut', () {
    test('clears auth state', () async {
      final svc = FakeAuthService()..queueResult(SignInResult.authenticated);
      final container = _makeContainer(svc);
      addTearDown(container.dispose);

      await container.read(authProvider.notifier).signIn('a@b.com', 'pw');
      expect(container.read(authProvider).status, AuthStatus.authenticated);

      await container.read(authProvider.notifier).signOut();
      expect(container.read(authProvider).status, AuthStatus.unauthenticated);
    });

    test('clears selected note', () async {
      final svc = FakeAuthService()..queueResult(SignInResult.authenticated);
      final container = _makeContainer(svc);
      addTearDown(container.dispose);

      await container.read(authProvider.notifier).signIn('a@b.com', 'pw');
      container.read(selectedNoteIdProvider.notifier).select('note-abc');
      expect(container.read(selectedNoteIdProvider), 'note-abc');

      await container.read(authProvider.notifier).signOut();
      expect(container.read(selectedNoteIdProvider), isNull);
    });
  });
}
