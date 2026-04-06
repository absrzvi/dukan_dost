/// Compile-time environment configuration.
///
/// Inject values at build time using `--dart-define`:
///   flutter build apk --release --dart-define=API_BASE_URL=https://api.example.com
///   flutter run --dart-define=API_BASE_URL=http://192.168.1.100:8000
///
/// When no `--dart-define=API_BASE_URL` is provided the default resolves to
/// the Android emulator's alias for the host machine (`10.0.2.2:8000`), which
/// allows local development with `flutter run` against a locally-running Django
/// server without any extra configuration.
///
/// This file is the SINGLE source of truth for the backend URL.
/// No other file in the codebase may hardcode a backend host or port.
const String apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:8000',
);
