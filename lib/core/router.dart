import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../models/basic_query.dart';
import '../models/customer.dart';
import '../models/entity.dart';
import '../models/furniture_material.dart';
import '../models/manufacturer.dart';
import '../models/manufacturer_query.dart';
import '../models/product.dart';
import '../models/product_category.dart';
import '../models/product_query.dart';
import '../repositories/category_repository.dart';
import '../repositories/crud_repository.dart';
import '../repositories/customer_repository.dart';
import '../repositories/manufacturer_repository.dart';
import '../repositories/material_repository.dart';
import '../repositories/product_repository.dart';
import '../screens/category_screens.dart';
import '../screens/customer_screens.dart';
import '../screens/forbidden_screen.dart';
import '../screens/home_screen.dart';
import '../screens/login_screen.dart';
import '../screens/manufacturer_detail_screen.dart';
import '../screens/manufacturer_form_screen.dart';
import '../screens/manufacturer_list_screen.dart';
import '../screens/material_screens.dart';
import '../screens/my_orders_screen.dart';
import '../screens/not_found_screen.dart';
import '../screens/product_detail_screen.dart';
import '../screens/product_form_screen.dart';
import '../screens/product_list_screen.dart';
import '../screens/register_screen.dart';
import '../screens/stats_screen.dart';
import '../screens/users_screen.dart';
import '../state/auth_notifier.dart';
import '../state/entity_detail_notifier.dart';
import '../state/entity_form_controller.dart';
import '../state/unsaved_changes_guard.dart';
import '../widgets/app_shell.dart';
import '../widgets/entity_form_page.dart';

GoRouter createRouter(UnsavedChangesGuard guard, AuthNotifier auth) {
  Future<bool> confirmExit(BuildContext context, GoRouterState state) async {
    if (!guard.dirty) return true;
    final leave = await confirmDiscardChanges(context);
    if (leave) guard.dirty = false;
    return leave;
  }

  List<RouteBase> entityRoutes<T extends Entity>({
    required String path,
    required Widget Function(GoRouterState state) list,
    required Widget detail,
    required Widget form,
    required CrudRepository<T, dynamic> Function(BuildContext) repository,
  }) {
    Widget withForm(BuildContext context, int? id) => ChangeNotifierProvider(
      key: ValueKey('$path-form-$id'),
      create: (c) => EntityFormController<T>(repository(c), id)..load(),
      child: form,
    );

    int? idOf(GoRouterState state) =>
        int.tryParse(state.pathParameters['id'] ?? '');

    return [
      GoRoute(path: path, builder: (context, state) => list(state)),
      GoRoute(
        path: '$path/new',
        onExit: confirmExit,
        redirect: (context, state) =>
            auth.permissions.redirectFor(state.matchedLocation),
        builder: (context, state) => withForm(context, null),
      ),
      GoRoute(
        path: '$path/:id',
        builder: (context, state) {
          final id = idOf(state);
          if (id == null) return NotFoundScreen(location: state.uri.toString());
          return ChangeNotifierProvider(
            key: ValueKey('$path-$id'),
            create: (c) => EntityDetailNotifier<T>(repository(c), id)..load(),
            child: detail,
          );
        },
      ),
      GoRoute(
        path: '$path/:id/edit',
        onExit: confirmExit,
        redirect: (context, state) =>
            auth.permissions.redirectFor(state.matchedLocation),
        builder: (context, state) {
          final id = idOf(state);
          if (id == null) return NotFoundScreen(location: state.uri.toString());
          return withForm(context, id);
        },
      ),
    ];
  }

  return GoRouter(
    initialLocation: '/',
    refreshListenable: auth,
    errorBuilder: (context, state) =>
        NotFoundScreen(location: state.uri.toString()),
    redirect: (context, state) {
      if (auth.isRestoring) return null;

      final loggedIn = auth.isAuthenticated;
      final target = state.matchedLocation;
      final isPublic = target == '/login' || target == '/register';

      if (!loggedIn && !isPublic) {
        return '/login?from=${Uri.encodeComponent(state.uri.toString())}';
      }
      if (loggedIn && isPublic) return '/';

      if (loggedIn && !isPublic) {
        final denied = auth.permissions.redirectFor(target);
        if (denied == '/forbidden' && target != '/forbidden') {
          return '/forbidden';
        }
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => LoginScreen(
          from: state.uri.queryParameters['from'],
        ),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
          GoRoute(
            path: '/forbidden',
            builder: (context, state) => const ForbiddenScreen(),
          ),
          GoRoute(
            path: '/my-orders',
            redirect: (context, state) =>
                auth.permissions.redirectFor('/my-orders'),
            builder: (context, state) => const MyOrdersScreen(),
          ),
          GoRoute(
            path: '/admin/users',
            redirect: (context, state) =>
                auth.permissions.redirectFor('/admin/users'),
            builder: (context, state) => const UsersScreen(),
          ),
          GoRoute(
            path: '/admin/stats',
            redirect: (context, state) =>
                auth.permissions.redirectFor('/admin/stats'),
            builder: (context, state) => const StatsScreen(),
          ),
          ...entityRoutes<Product>(
            path: '/products',
            list: (s) => ProductListScreen(
              query: ProductQuery.fromParameters(s.uri.queryParameters),
            ),
            detail: const ProductDetailScreen(),
            form: const ProductFormScreen(),
            repository: (c) => c.read<ProductRepository>(),
          ),
          ...entityRoutes<Manufacturer>(
            path: '/manufacturers',
            list: (s) => ManufacturerListScreen(
              query: ManufacturerQuery.fromParameters(s.uri.queryParameters),
            ),
            detail: const ManufacturerDetailScreen(),
            form: const ManufacturerFormScreen(),
            repository: (c) => c.read<ManufacturerRepository>(),
          ),
          ...entityRoutes<ProductCategory>(
            path: '/categories',
            list: (s) => CategoryListScreen(
              query: BasicQuery.fromParameters(
                categoryQuerySpec,
                s.uri.queryParameters,
              ),
            ),
            detail: const CategoryDetailScreen(),
            form: const CategoryFormScreen(),
            repository: (c) => c.read<CategoryRepository>(),
          ),
          ...entityRoutes<FurnitureMaterial>(
            path: '/materials',
            list: (s) => MaterialListScreen(
              query: BasicQuery.fromParameters(
                materialQuerySpec,
                s.uri.queryParameters,
              ),
            ),
            detail: const MaterialDetailScreen(),
            form: const MaterialFormScreen(),
            repository: (c) => c.read<MaterialRepository>(),
          ),
          ...entityRoutes<Customer>(
            path: '/customers',
            list: (s) => CustomerListScreen(
              query: BasicQuery.fromParameters(
                customerQuerySpec,
                s.uri.queryParameters,
              ),
            ),
            detail: const CustomerDetailScreen(),
            form: const CustomerFormScreen(),
            repository: (c) => c.read<CustomerRepository>(),
          ),
        ],
      ),
    ],
  );
}
