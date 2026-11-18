import 'package:dio/dio.dart';

import '../models/app_user.dart';
import 'api_exception.dart';
import 'api_session.dart';

/// Клиент эндпоинтов `/auth/*`, `/users`, `/stats`, `/my-orders`.
class AuthApi {
  AuthApi(this._dio);

  final Dio _dio;

  Options get _skip => Options(extra: {ApiSession.skipAuth: true});

  Future<AuthTokens> login(String username, String password) => guard(() async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/login',
      data: {'username': username, 'password': password},
      options: _skip,
    );
    return AuthTokens.fromJson(response.data!);
  });

  Future<AuthTokens> register({
    required String username,
    required String password,
    required String fullName,
  }) => guard(() async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/register',
      data: {
        'username': username,
        'password': password,
        'fullName': fullName,
      },
      options: _skip,
    );
    return AuthTokens.fromJson(response.data!);
  });

  Future<AuthTokens> refresh(String refreshToken) => guard(() async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/refresh',
      data: {'refreshToken': refreshToken},
      options: _skip,
    );
    return AuthTokens.fromJson(response.data!);
  });

  Future<AppUser> me() => guard(() async {
    final response = await _dio.get<Map<String, dynamic>>('/auth/me');
    return AppUser.fromJson(response.data!);
  });

  Future<void> logout(String? refreshToken) => guard(() async {
    await _dio.post<void>(
      '/auth/logout',
      data: {'refreshToken': refreshToken},
      options: _skip,
    );
  });

  Future<List<AppUser>> listUsers() => guard(() async {
    final response = await _dio.get<Map<String, dynamic>>('/users');
    final items = response.data!['items'] as List<dynamic>? ?? const [];
    return [
      for (final item in items) AppUser.fromJson(item as Map<String, dynamic>),
    ];
  });

  Future<AppUser> updateUserRole(int id, RoleUpdate update) => guard(() async {
    final response = await _dio.put<Map<String, dynamic>>(
      '/users/$id',
      data: update.toJson(),
    );
    return AppUser.fromJson(response.data!);
  });

  Future<Map<String, int>> stats() => guard(() async {
    final response = await _dio.get<Map<String, dynamic>>('/stats');
    final data = response.data!;
    return {
      for (final e in data.entries)
        if (e.value is num) e.key: (e.value as num).toInt(),
    };
  });

  Future<List<Map<String, dynamic>>> myOrders() => guard(() async {
    final response = await _dio.get<Map<String, dynamic>>('/my-orders');
    final items = response.data!['items'] as List<dynamic>? ?? const [];
    return [for (final item in items) Map<String, dynamic>.from(item as Map)];
  });
}

class RoleUpdate {
  const RoleUpdate({required this.role, this.fullName});

  final String role;
  final String? fullName;

  Map<String, dynamic> toJson() => {
    'role': role,
    if (fullName != null) 'fullName': fullName,
  };
}
