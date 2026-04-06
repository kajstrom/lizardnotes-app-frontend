import 'package:flutter_test/flutter_test.dart';
import 'package:lizardnotes_app/config/app_config.dart';

void main() {
  group('AppConfig.assertValid', () {
    test('throws StateError when dart-define values are empty', () {
      // In the test environment no --dart-define flags are passed, so every
      // String.fromEnvironment returns '' — assertValid() must throw on the
      // first missing value (API_URL).
      expect(AppConfig.assertValid, throwsStateError);
    });

    test('apiUrl is empty without dart-define', () {
      expect(AppConfig.apiUrl, isEmpty);
    });

    test('cognitoUserPoolId is empty without dart-define', () {
      expect(AppConfig.cognitoUserPoolId, isEmpty);
    });

    test('cognitoAppClientId is empty without dart-define', () {
      expect(AppConfig.cognitoAppClientId, isEmpty);
    });
  });
}
