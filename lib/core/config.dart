class AppConfig {
  const AppConfig._();

  /// Адрес API. В коде нет ни одного другого упоминания адреса сервера.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8090',
  );

  static const String dataSource = String.fromEnvironment(
    'DATA_SOURCE',
    defaultValue: 'api',
  );

  static bool get useApi => dataSource != 'local';
}
