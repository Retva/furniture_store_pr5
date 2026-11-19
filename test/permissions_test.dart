import 'package:flutter_test/flutter_test.dart';
import 'package:furniture_store/core/permissions.dart';
import 'package:furniture_store/models/app_user.dart';
import 'package:furniture_store/models/role.dart';
import 'package:furniture_store/screens/register_screen.dart';

AppUser user(Role role) =>
    AppUser(id: '1', username: role.code, fullName: role.label, role: role);

void main() {
  group('Role.fromCode', () {
    test('незнакомая роль становится viewer, а не admin', () {
      expect(Role.fromCode('sudo'), Role.viewer);
      expect(Role.fromCode(null), Role.viewer);
      expect(Role.fromCode('admin'), Role.admin);
    });
  });

  group('Permissions по ролям', () {
    test('покупатель видит каталог и свои заказы, но не управляет', () {
      final p = Permissions(user(Role.viewer));
      expect(p.canBrowseCatalog, isTrue);
      expect(p.canViewMyOrders, isTrue);
      expect(p.canManageCatalog, isFalse);
      expect(p.canManageCustomers, isFalse);
      expect(p.canManageUsers, isFalse);
      expect(p.canViewStats, isFalse);
      expect(p.canHardDelete, isFalse);
      expect(p.redirectFor('/my-orders'), isNull);
      expect(p.redirectFor('/customers'), '/forbidden');
      expect(p.redirectFor('/admin/users'), '/forbidden');
      expect(p.redirectFor('/products/new'), '/forbidden');
    });

    test('менеджер управляет каталогом и покупателями, без админ-разделов', () {
      final p = Permissions(user(Role.manager));
      expect(p.canManageCatalog, isTrue);
      expect(p.canManageCustomers, isTrue);
      expect(p.canPlaceOrders, isTrue);
      expect(p.canViewMyOrders, isFalse);
      expect(p.canManageUsers, isFalse);
      expect(p.canViewStats, isFalse);
      expect(p.canHardDelete, isFalse);
      expect(p.canRestore, isFalse);
      expect(p.redirectFor('/customers'), isNull);
      expect(p.redirectFor('/products/new'), isNull);
      expect(p.redirectFor('/my-orders'), '/forbidden');
      expect(p.redirectFor('/admin/stats'), '/forbidden');
    });

    test(
      'администратор видит пользователей, статистику и жёсткое удаление',
      () {
        final p = Permissions(user(Role.admin));
        expect(p.canManageCatalog, isTrue);
        expect(p.canManageUsers, isTrue);
        expect(p.canViewStats, isTrue);
        expect(p.canHardDelete, isTrue);
        expect(p.canRestore, isTrue);
        expect(p.canViewDeleted, isTrue);
        expect(p.canViewMyOrders, isFalse);
        expect(p.redirectFor('/admin/users'), isNull);
        expect(p.redirectFor('/admin/stats'), isNull);
        expect(p.redirectFor('/my-orders'), '/forbidden');
      },
    );

    test(
      'гость (нет пользователя) никуда, кроме публичных экранов, не проходит',
      () {
        const p = Permissions(null);
        expect(p.isAuthenticated, isFalse);
        expect(p.canBrowseCatalog, isFalse);
        expect(p.redirectFor('/'), '/login');
        expect(p.redirectFor('/products'), '/login');
      },
    );

    test('навигация скрывает разделы чужих ролей', () {
      expect(Permissions(user(Role.viewer)).canSeeNav('/admin/users'), isFalse);
      expect(Permissions(user(Role.viewer)).canSeeNav('/my-orders'), isTrue);
      expect(Permissions(user(Role.manager)).canSeeNav('/customers'), isTrue);
      expect(
        Permissions(user(Role.manager)).canSeeNav('/admin/stats'),
        isFalse,
      );
      expect(Permissions(user(Role.admin)).canSeeNav('/admin/users'), isTrue);
      expect(Permissions(user(Role.admin)).canSeeNav('/my-orders'), isFalse);
    });
  });

  group('Проверка пароля при регистрации', () {
    test('короткий пароль, без цифры и без спецсимвола отклоняются', () {
      expect(RegisterScreen.passwordValidator('short'), isNotNull);
      expect(RegisterScreen.passwordValidator('longenough'), isNotNull);
      expect(RegisterScreen.passwordValidator('longenough1'), isNotNull);
      expect(RegisterScreen.passwordValidator('longenough1!'), isNull);
    });
  });
}
