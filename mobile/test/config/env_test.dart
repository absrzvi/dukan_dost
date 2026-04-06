import 'package:flutter_test/flutter_test.dart';
import 'package:dukan_dost/config/env.dart';

void main() {
  group('env.dart — apiBaseUrl', () {
    test('default value is the Android emulator localhost alias', () {
      // When no --dart-define=API_BASE_URL is passed (as in `flutter test`),
      // the constant must resolve to the emulator default.
      expect(apiBaseUrl, equals('http://10.0.2.2:8000'));
    });

    test('apiBaseUrl is a non-empty string', () {
      expect(apiBaseUrl, isNotEmpty);
    });

    test('apiBaseUrl starts with http', () {
      expect(apiBaseUrl, startsWith('http'));
    });
  });
}
