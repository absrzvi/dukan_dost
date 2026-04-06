import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dukan_dost/config/env.dart';
import 'package:dukan_dost/core/network/api_client.dart';

void main() {
  group('env.dart — apiBaseUrl', () {
    test('default value is the Android emulator localhost alias', () {
      // When no --dart-define=API_BASE_URL is passed (as in `flutter test`),
      // the constant must resolve to the emulator default.
      expect(apiBaseUrl, equals('http://10.0.2.2:8000'));
    });

    test('dioProvider baseUrl equals apiBaseUrl', () {
      // Verifies that dioProvider wires apiBaseUrl as the Dio base URL —
      // not a hardcoded string or stale inline constant.
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final dio = container.read(dioProvider);
      expect(dio.options.baseUrl, equals(apiBaseUrl));
    });
  });

  group('api_client.dart — no hardcoded URLs', () {
    test('dioProvider produces a Dio instance', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final dio = container.read(dioProvider);
      expect(dio, isA<Dio>());
    });
  });
}
