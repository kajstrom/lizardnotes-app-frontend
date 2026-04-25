import 'package:amazon_cognito_identity_dart_2/cognito.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../config/app_config.dart';

/// Result of a sign-in or challenge-response operation.
enum SignInResult {
  authenticated,
  requiresNewPassword,
  requiresMfaSetup,
  requiresMfaCode,
}

/// Abstract interface over Cognito auth operations.
///
/// Exists so [AuthNotifier] can be tested without hitting real AWS endpoints.
abstract class AuthService {
  Future<SignInResult> signIn(String email, String password);
  Future<SignInResult> confirmNewPassword(String newPassword);
  Future<String> setupMfa(); // returns otpauth:// URI for QR code
  Future<void> verifyMfaSetup(String code);
  Future<SignInResult> confirmMfaCode(String code);
  Future<void> forgotPassword(String email);
  Future<void> confirmForgotPassword(
      String email, String code, String newPassword);
  Future<void> signOut();
  Future<bool> tryRestoreSession();

  /// Returns a valid access JWT, refreshing the session if needed.
  ///
  /// Returns `null` if no session is available or the refresh token has
  /// expired/been rejected — callers should treat this as a forced sign-out.
  Future<String?> getValidAccessToken();

  CognitoUserSession? get currentSession;
}

class CognitoAuthService implements AuthService {
  CognitoAuthService()
      : _pool = CognitoUserPool(
          AppConfig.cognitoUserPoolId,
          AppConfig.cognitoAppClientId,
        );

  final CognitoUserPool _pool;
  CognitoUser? _user;
  CognitoUserSession? _session;

  static const _kIdToken = 'auth_id_token';
  static const _kAccessToken = 'auth_access_token';
  static const _kRefreshToken = 'auth_refresh_token';
  static const _kUsername = 'auth_username';

  @override
  CognitoUserSession? get currentSession => _session;

  @override
  Future<SignInResult> signIn(String email, String password) async {
    _user = CognitoUser(email, _pool);
    final authDetails =
        AuthenticationDetails(username: email, password: password);
    try {
      _session = await _user!.authenticateUser(authDetails);
      await _persist();
      return SignInResult.authenticated;
    } on CognitoUserNewPasswordRequiredException {
      return SignInResult.requiresNewPassword;
    } on CognitoUserMfaSetupException {
      return SignInResult.requiresMfaSetup;
    } on CognitoUserTotpRequiredException {
      return SignInResult.requiresMfaCode;
    }
  }

  @override
  Future<SignInResult> confirmNewPassword(String newPassword) async {
    try {
      _session = await _user!.sendNewPasswordRequiredAnswer(newPassword);
      if (_session != null) await _persist();
      return SignInResult.authenticated;
    } on CognitoUserMfaSetupException {
      return SignInResult.requiresMfaSetup;
    } on CognitoUserTotpRequiredException {
      return SignInResult.requiresMfaCode;
    }
  }

  @override
  Future<String> setupMfa() async {
    final secret = await _user!.associateSoftwareToken();
    final email = _user?.username ?? '';
    return 'otpauth://totp/LizardNotes:$email'
        '?secret=$secret&issuer=LizardNotes';
  }

  @override
  Future<void> verifyMfaSetup(String code) async {
    final ok = await _user!.verifySoftwareToken(
      totpCode: code,
      friendlyDeviceName: 'LizardNotes',
    );
    if (!ok) throw Exception('TOTP verification failed');
    // Attempt to retrieve session post-setup; not all flows return one here.
    try {
      _session = await _user!.getSession();
      if (_session != null) await _persist();
    } catch (_) {
      // Session unavailable — caller should handle by re-authenticating.
    }
  }

  @override
  Future<SignInResult> confirmMfaCode(String code) async {
    _session = await _user!.sendMFACode(code, 'SOFTWARE_TOKEN_MFA');
    if (_session != null) await _persist();
    return SignInResult.authenticated;
  }

  @override
  Future<void> forgotPassword(String email) async {
    _user = CognitoUser(email, _pool);
    await _user!.forgotPassword();
  }

  @override
  Future<void> confirmForgotPassword(
      String email, String code, String newPassword) async {
    _user ??= CognitoUser(email, _pool);
    await _user!.confirmPassword(code, newPassword);
  }

  @override
  Future<void> signOut() async {
    await _user?.signOut();
    _user = null;
    _session = null;
    await _clearPersisted();
  }

  @override
  Future<bool> tryRestoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString(_kUsername);
    final idJwt = prefs.getString(_kIdToken);
    final accessJwt = prefs.getString(_kAccessToken);
    final refreshStr = prefs.getString(_kRefreshToken);

    if (username == null) return false;

    _user = CognitoUser(username, _pool);
    final refreshToken =
        refreshStr != null ? CognitoRefreshToken(refreshStr) : null;

    // The CognitoIdToken/CognitoAccessToken constructors parse the JWT and
    // throw on malformed input — don't let a corrupt cached token abort the
    // whole restore (the refresh token may still be good).
    if (idJwt != null && accessJwt != null) {
      try {
        _session = CognitoUserSession(
          CognitoIdToken(idJwt),
          CognitoAccessToken(accessJwt),
          refreshToken: refreshToken,
        );
      } catch (_) {
        _session = null;
      }
    }

    if (await getValidAccessToken() != null) return true;

    // Cached id/access tokens were unusable; fall back to a refresh-only path.
    if (refreshToken != null) {
      try {
        _session = await _user!.refreshSession(refreshToken);
        if (_session != null) {
          await _persist();
          return true;
        }
      } catch (_) {
        // fall through to clear
      }
    }
    _session = null;
    await _clearPersisted();
    return false;
  }

  @override
  Future<String?> getValidAccessToken() async {
    // isValid() parses the JWT and can throw on malformed tokens (e.g. after
    // a manual localStorage edit). Treat a throw as "not valid" and fall
    // through to refresh rather than bubbling up.
    bool sessionValid = false;
    if (_session != null) {
      try {
        sessionValid = _session!.isValid();
      } catch (_) {
        sessionValid = false;
      }
    }
    if (sessionValid) {
      return _session!.getAccessToken().getJwtToken();
    }

    final refreshToken = _session?.getRefreshToken();
    if (_user == null || refreshToken == null) {
      _session = null;
      await _clearPersisted();
      return null;
    }

    try {
      _session = await _user!.refreshSession(refreshToken);
      if (_session == null) {
        await _clearPersisted();
        return null;
      }
      await _persist();
      return _session!.getAccessToken().getJwtToken();
    } catch (_) {
      _session = null;
      await _clearPersisted();
      return null;
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setString(_kIdToken, _session!.getIdToken().getJwtToken() ?? ''),
      prefs.setString(
          _kAccessToken, _session!.getAccessToken().getJwtToken() ?? ''),
      prefs.setString(
          _kRefreshToken, _session!.getRefreshToken()?.getToken() ?? ''),
      prefs.setString(_kUsername, _user?.username ?? ''),
    ]);
  }

  Future<void> _clearPersisted() async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.remove(_kIdToken),
      prefs.remove(_kAccessToken),
      prefs.remove(_kRefreshToken),
      prefs.remove(_kUsername),
    ]);
  }
}
