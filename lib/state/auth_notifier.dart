import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/api_exception.dart';
import '../api/auth_api.dart';
import '../core/permissions.dart';
import '../models/app_user.dart';
import '../models/role.dart';

/// Сессия пользователя: токены и роль в localStorage (`flutter.auth_*`).
///
/// Ключ `auth_role` можно поменять в DevTools — но права даёт только сервер.
/// Если значение в localStorage не совпадает с `/auth/me`, показывается
/// «Недостаточно прав» (учебная демонстрация подмены роли на клиенте).
class AuthNotifier extends ChangeNotifier {
  AuthNotifier(this._prefs, this.api);

  static const _kAccess = 'auth_access_token';
  static const _kRefresh = 'auth_refresh_token';
  static const _kRole = 'auth_role';
  static const _kSessionStarted = 'auth_session_started_at';
  static const _kLastActivity = 'auth_last_activity_at';

  /// Общая длительность сессии независимо от активности.
  static const sessionMaxDuration = Duration(hours: 8);

  /// Выход по неактивности.
  static const inactivityTimeout = Duration(minutes: 3);

  /// Предупреждение до выхода по неактивности.
  static const inactivityWarning = Duration(seconds: 30);

  final SharedPreferences _prefs;

  /// Подменяется после создания Dio с [ApiSession], чтобы /auth/me шёл с токеном.
  AuthApi api;

  AppUser? _user;
  String? _accessToken;
  String? _refreshToken;
  DateTime? _sessionStartedAt;
  bool _restoring = true;
  bool _roleTampered = false;
  Future<void>? _refreshInFlight;

  AppUser? get user => _user;
  String? get accessToken => _accessToken;
  bool get isAuthenticated => _user != null;
  bool get isRestoring => _restoring;

  /// localStorage `auth_role` не совпадает с ролью на сервере.
  bool get roleTampered => _roleTampered;

  /// Роль, записанная в localStorage (может отличаться от [user.role]).
  Role? get storedRole {
    final code = _prefs.getString(_kRole);
    return code == null ? null : Role.fromCode(code);
  }

  Permissions get permissions => Permissions(_user);
  bool has(Role role) => permissions.has(role);

  DateTime? get sessionStartedAt => _sessionStartedAt;

  /// Восстановление сессии при запуске — до построения маршрутов.
  Future<void> restore() async {
    _restoring = true;
    notifyListeners();
    try {
      final access = _prefs.getString(_kAccess);
      final refresh = _prefs.getString(_kRefresh);
      final startedMs = _prefs.getInt(_kSessionStarted);
      if (startedMs != null) {
        _sessionStartedAt = DateTime.fromMillisecondsSinceEpoch(startedMs);
      }

      if (_sessionExpiredByMaxDuration()) {
        await logout(silent: true);
        return;
      }

      final lastActivityMs = _prefs.getInt(_kLastActivity);
      if (lastActivityMs != null) {
        final idle = DateTime.now().difference(
          DateTime.fromMillisecondsSinceEpoch(lastActivityMs),
        );
        if (idle >= inactivityTimeout) {
          await logout(silent: true);
          return;
        }
      }

      if (access == null) return;
      _accessToken = access;
      _refreshToken = refresh;
      try {
        final me = await api.me();
        _user = me;
        _checkStoredRole(me);
      } on UnauthorizedException {
        if (refresh != null) {
          try {
            await _refreshWith(refresh);
          } catch (_) {
            await logout(silent: true);
          }
        } else {
          await logout(silent: true);
        }
      } catch (_) {
        // Сервер недоступен: токены оставляем, пользователя пока нет.
      }
    } finally {
      _restoring = false;
      notifyListeners();
    }
  }

  Future<void> login(String username, String password) async {
    final result = await api.login(username, password);
    await _applyTokens(result);
  }

  Future<void> register({
    required String email,
    required String username,
    required String password,
    required String fullName,
  }) async {
    final result = await api.register(
      email: email,
      username: username,
      password: password,
      fullName: fullName,
    );
    await _applyTokens(result);
  }

  Future<void> logout({bool silent = false}) async {
    final refresh = _refreshToken;
    _user = null;
    _accessToken = null;
    _refreshToken = null;
    _sessionStartedAt = null;
    _roleTampered = false;
    await _prefs.remove(_kAccess);
    await _prefs.remove(_kRefresh);
    await _prefs.remove(_kRole);
    await _prefs.remove(_kSessionStarted);
    await _prefs.remove(_kLastActivity);
    if (refresh != null) {
      try {
        await api.logout(refresh);
      } catch (_) {}
    }
    if (!silent) notifyListeners();
  }

  /// Обновление токена; параллельные вызовы ждут один и тот же запрос.
  Future<void> refreshTokens() {
    return _refreshInFlight ??= () async {
      final refresh = _refreshToken ?? _prefs.getString(_kRefresh);
      if (refresh == null) {
        await logout(silent: true);
        throw const UnauthorizedException('Нет токена обновления.');
      }
      await _refreshWith(refresh);
    }().whenComplete(() => _refreshInFlight = null);
  }

  Future<void> _refreshWith(String refresh) async {
    final result = await api.refresh();
    await _applyTokens(result, keepSessionStart: true);
  }

  Future<void> _applyTokens(
    AuthTokens result, {
    bool keepSessionStart = false,
  }) async {
    _accessToken = result.accessToken;
    _refreshToken = result.refreshToken;
    _user = result.user;
    await _prefs.setString(_kAccess, result.accessToken);
    await _prefs.setString(_kRefresh, result.refreshToken);
    if (!keepSessionStart) {
      // Вход/регистрация — синхронизируем роль в localStorage с сервером.
      _roleTampered = false;
      await _prefs.setString(_kRole, result.user.role.code);
    } else {
      // Refresh: права с сервера; подмена auth_role → «Недостаточно прав».
      _checkStoredRole(result.user);
    }
    if (!keepSessionStart || _sessionStartedAt == null) {
      _sessionStartedAt = DateTime.now();
      await _prefs.setInt(
        _kSessionStarted,
        _sessionStartedAt!.millisecondsSinceEpoch,
      );
    }
    await touchActivity();
    notifyListeners();
  }

  /// Записать роль в localStorage. Если она не совпадает с серверной —
  /// включается [roleTampered] и открывается экран «Недостаточно прав».
  Future<void> setLocalRole(Role role) async {
    await _prefs.setString(_kRole, role.code);
    final current = _user;
    if (current == null) return;
    _roleTampered = role != current.role;
    notifyListeners();
  }

  /// Вернуть `auth_role` к роли с сервера и снять отказ в доступе.
  Future<void> restoreStoredRole() async {
    final current = _user;
    if (current == null) return;
    await _prefs.setString(_kRole, current.role.code);
    _roleTampered = false;
    notifyListeners();
  }

  void _checkStoredRole(AppUser user) {
    final stored = _prefs.getString(_kRole);
    if (stored == null) {
      _prefs.setString(_kRole, user.role.code);
      _roleTampered = false;
      return;
    }
    _roleTampered = Role.fromCode(stored) != user.role;
  }

  Future<void> touchActivity() async {
    await _prefs.setInt(_kLastActivity, DateTime.now().millisecondsSinceEpoch);
  }

  bool _sessionExpiredByMaxDuration() {
    final started = _sessionStartedAt;
    if (started == null) return false;
    return DateTime.now().difference(started) >= sessionMaxDuration;
  }

  /// Проверка лимита сессии (вызывается таймером и при действиях).
  Future<bool> checkSessionLimits() async {
    if (!isAuthenticated) return false;
    if (_sessionExpiredByMaxDuration()) {
      await logout();
      return true;
    }
    return false;
  }

  /// Локальный режим без сервера: сразу «вошли» как администратор.
  void adoptLocalAdmin() {
    _user = const AppUser(
      id: '',
      username: 'local',
      fullName: 'Локальный администратор',
      role: Role.admin,
    );
    _restoring = false;
    _sessionStartedAt = DateTime.now();
    notifyListeners();
  }

  /// Для тестов: задать токены без обращения к серверу.
  void adoptTokensForTest({
    required String accessToken,
    String refreshToken = 'refresh-token',
    AppUser user = const AppUser(
      id: '1',
      username: 'manager',
      fullName: 'Менеджер',
      role: Role.manager,
    ),
  }) {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    _user = user;
    _restoring = false;
  }
}
