import '../models/role.dart';
import '../state/auth_notifier.dart';

/// Мост между перехватчиком Dio и [AuthNotifier]: токен и роль берутся
/// из сессии пользователя, а не из зашитой служебной учётки.
class ApiSession {
  ApiSession(this.auth);

  final AuthNotifier auth;

  String? get accessToken => auth.accessToken;

  String? get role => auth.user?.role.code;

  String? get username => auth.user?.username;

  /// Пометка запроса, которому токен не нужен (вход, регистрация, refresh).
  static const String skipAuth = 'skipAuth';

  /// Учётные записи мок-сервера — для подсказок на экране входа.
  static const Map<String, String> demoAccounts = {
    'admin': 'admin123',
    'manager': 'manager123',
    'viewer': 'viewer123',
  };

  static const Map<String, Role> demoRoles = {
    'admin': Role.admin,
    'manager': Role.manager,
    'viewer': Role.viewer,
  };
}
