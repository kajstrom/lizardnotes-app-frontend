import 'package:flutter_test/flutter_test.dart';
import 'package:lizardnotes_app/main.dart';

void main() {
  // Tests run on the Dart VM (kIsWeb == false) with asserts enabled, the same
  // conditions as a debug Android build. Web-only platform setup must be
  // guarded, or main() throws before runApp() and the app never draws a frame.
  test('configurePlatform does not throw off the web', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    expect(configurePlatform, returnsNormally);
  });
}
