/// Build-time configuration, passed with `--dart-define` or
/// `--dart-define-from-file=env/<flavor>.json`.
abstract final class Env {
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://gold-sardine-283964.hostingersite.com/api/v1',
  );
  static const flavor = String.fromEnvironment('FLAVOR', defaultValue: 'prod');
  static bool get isDev => flavor == 'dev';
}
