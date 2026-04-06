abstract final class AppConfig {
  static const String apiUrl = String.fromEnvironment('API_URL');
  static const String cognitoUserPoolId =
      String.fromEnvironment('COGNITO_USER_POOL_ID');
  static const String cognitoAppClientId =
      String.fromEnvironment('COGNITO_APP_CLIENT_ID');

  static void assertValid() {
    if (apiUrl.isEmpty) {
      throw StateError(
        'dart-define API_URL is required but was not provided. '
        'Pass --dart-define=API_URL=<value> at build time.',
      );
    }
    if (cognitoUserPoolId.isEmpty) {
      throw StateError(
        'dart-define COGNITO_USER_POOL_ID is required but was not provided. '
        'Pass --dart-define=COGNITO_USER_POOL_ID=<value> at build time.',
      );
    }
    if (cognitoAppClientId.isEmpty) {
      throw StateError(
        'dart-define COGNITO_APP_CLIENT_ID is required but was not provided. '
        'Pass --dart-define=COGNITO_APP_CLIENT_ID=<value> at build time.',
      );
    }
  }
}
