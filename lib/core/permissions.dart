import '../models/role.dart';
import '../models/app_user.dart';

/// Все проверки прав собраны здесь. Экраны спрашивают «можно ли?», а не сравнивают роль сами — иначе условия расползутся по двадцати файлам.
/// Это удобство интерфейса. Решение «разрешить операцию» принимает сервер.
class Permissions {
  const Permissions(this.user);

  final AppUser? user;

  bool get isAuthenticated => user != null;

  bool has(Role role) => user != null && user!.role.atLeast(role);

  bool get canBrowseCatalog => isAuthenticated;

  /// Создание и правка каталога, справочников, покупателей, заказов.
  bool get canManageCatalog => has(Role.manager);

  bool get canManageCustomers => has(Role.manager);

  bool get canPlaceOrders => has(Role.manager);

  /// Физическое удаление и восстановление — только администратор.
  bool get canHardDelete => has(Role.admin);

  bool get canRestore => has(Role.admin);

  bool get canViewDeleted => has(Role.admin);

  bool get canManageUsers => has(Role.admin);

  bool get canViewStats => has(Role.admin);

  /// Личный кабинет заказов — только роль покупателя.
  bool get canViewMyOrders => user?.role == Role.viewer;

  /// Разделы навигации, видимые текущей роли.
  bool canSeeNav(String path) {
    return switch (path) {
      '/products' ||
      '/manufacturers' ||
      '/categories' ||
      '/materials' => canBrowseCatalog,
      '/customers' => canManageCustomers,
      '/my-orders' => canViewMyOrders,
      '/admin/users' => canManageUsers,
      '/admin/stats' => canViewStats,
      _ => isAuthenticated,
    };
  }

  /// Минимальная роль для маршрута; `null` — достаточно войти.
  Role? requiredRoleFor(String path) {
    if (path.startsWith('/admin/')) return Role.admin;
    if (path == '/my-orders' || path.startsWith('/my-orders/')) {
      return Role.viewer;
    }
    if (path == '/customers' || path.startsWith('/customers/')) {
      return Role.manager;
    }
    if (path.endsWith('/new') || path.endsWith('/edit')) {
      return Role.manager;
    }
    return null;
  }

  /// `null` — переход разрешён, иначе адрес экрана отказа.
  String? redirectFor(String path) {
    if (!isAuthenticated) return '/login';
    if (path == '/my-orders' || path.startsWith('/my-orders/')) {
      return canViewMyOrders ? null : '/forbidden';
    }
    final required = requiredRoleFor(path);
    if (required == null) return null;
    if (required == Role.viewer) {
      return canViewMyOrders ? null : '/forbidden';
    }
    return has(required) ? null : '/forbidden';
  }
}
