import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api/api_client.dart';
import 'api/api_session.dart';
import 'api/auth_api.dart';
import 'api/debug_options.dart';
import 'core/config.dart';
import 'core/router.dart';
import 'core/scroll_behavior.dart';
import 'models/customer.dart';
import 'models/furniture_material.dart';
import 'models/manufacturer.dart';
import 'models/product.dart';
import 'models/product_category.dart';
import 'repositories/api/api_repositories.dart';
import 'repositories/category_repository.dart';
import 'repositories/customer_repository.dart';
import 'repositories/local_category_repository.dart';
import 'repositories/local_customer_repository.dart';
import 'repositories/local_manufacturer_repository.dart';
import 'repositories/local_material_repository.dart';
import 'repositories/local_product_repository.dart';
import 'repositories/local_storage.dart';
import 'repositories/manufacturer_repository.dart';
import 'repositories/material_repository.dart';
import 'repositories/network_simulator.dart';
import 'repositories/order_repository.dart';
import 'repositories/product_repository.dart';
import 'state/auth_notifier.dart';
import 'state/debug_settings_notifier.dart';
import 'state/manufacturer_list_notifier.dart';
import 'state/other_list_notifiers.dart';
import 'state/product_list_notifier.dart';
import 'state/reference_data_notifier.dart';
import 'state/unsaved_changes_guard.dart';
import 'widgets/inactivity_watcher.dart';

class FurnitureStoreApp extends StatefulWidget {
  const FurnitureStoreApp({
    super.key,
    required this.store,
    required this.report,
    required this.prefs,
    this.network,
  });

  final KeyValueStore store;
  final StorageReport report;
  final SharedPreferences prefs;
  final NetworkSimulator? network;

  @override
  State<FurnitureStoreApp> createState() => _FurnitureStoreAppState();
}

class _FurnitureStoreAppState extends State<FurnitureStoreApp> {
  late final NetworkSimulator _network = widget.network ?? NetworkSimulator();
  final UnsavedChangesGuard _guard = UnsavedChangesGuard();
  final GlobalKey<ScaffoldMessengerState> _messenger = GlobalKey();

  late final AuthNotifier _auth;
  late final AuthApi _authApi;
  late final GoRouter _router;

  late final ProductRepository _products;
  late final ManufacturerRepository _manufacturers;
  late final CategoryRepository _categories;
  late final MaterialRepository _materials;
  late final CustomerRepository _customers;
  OrderRepository? _orders;

  late final DebugSettingsNotifier _debug;
  late final ReferenceDataNotifier _refs;

  bool _ready = false;
  Timer? _sessionTimer;

  EntityStore<T> _storeFor<T>(
    String key,
    String title,
    T Function(Map<String, dynamic>) fromJson,
    Map<String, dynamic> Function(T) toJson,
  ) => EntityStore<T>(
    store: widget.store,
    key: key,
    title: title,
    fromJson: fromJson,
    toJson: toJson,
    report: widget.report,
  );

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    if (AppConfig.useApi) {
      _initApi();
    } else {
      _initLocal();
    }

    _router = createRouter(_guard, _auth);
    if (AppConfig.useApi) {
      await _auth.restore();
    } else {
      _auth.adoptLocalAdmin();
    }

    _sessionTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      final ended = await _auth.checkSessionLimits();
      if (ended && mounted) {
        _messenger.currentState?.showSnackBar(
          const SnackBar(
            content: Text('Сессия завершена: истекло максимальное время.'),
          ),
        );
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final message in widget.report.messages) {
        _messenger.currentState?.showSnackBar(
          SnackBar(
            content: Text(message),
            duration: const Duration(seconds: 8),
          ),
        );
      }
      widget.report.messages.clear();
    });

    if (mounted) setState(() => _ready = true);
  }

  void _initApi() {
    final options = DebugOptions();
    final bootstrapDio = buildDio(
      baseUrl: AppConfig.apiBaseUrl,
      debug: options,
      log: debugPrint,
    );
    _auth = AuthNotifier(widget.prefs, AuthApi(bootstrapDio));
    final session = ApiSession(_auth);
    final dio = buildDio(
      baseUrl: AppConfig.apiBaseUrl,
      session: session,
      debug: options,
      log: debugPrint,
    );
    _authApi = AuthApi(dio);
    _auth.api = _authApi;

    final categories = ApiCategoryRepository(dio);
    final manufacturers = ApiManufacturerRepository(dio);
    final materials = ApiMaterialRepository(dio);
    _products = ApiProductRepository(dio);
    _manufacturers = manufacturers;
    _categories = categories;
    _materials = materials;
    _customers = ApiCustomerRepository(dio);
    _orders = ApiOrderRepository(dio);

    _debug = DebugSettingsNotifier(options: options);
    _refs = ReferenceDataNotifier(categories, manufacturers, materials);

    categories.addChangeListener(_refs.markStale);
    manufacturers.addChangeListener(_refs.markStale);
    materials.addChangeListener(_refs.markStale);
  }

  void _initLocal() {
    final products = LocalProductRepository(
      network: _network,
      store: _storeFor<Product>(
        StorageKeys.products,
        'Товары',
        Product.fromJson,
        (p) => p.toJson(),
      ),
    );
    _manufacturers = LocalManufacturerRepository(
      network: _network,
      usageCount: products.countByManufacturer,
      store: _storeFor<Manufacturer>(
        StorageKeys.manufacturers,
        'Производители',
        Manufacturer.fromJson,
        (m) => m.toJson(),
      ),
    );
    _categories = LocalCategoryRepository(
      network: _network,
      usageCount: products.countByCategory,
      store: _storeFor<ProductCategory>(
        StorageKeys.categories,
        'Категории',
        ProductCategory.fromJson,
        (c) => c.toJson(),
      ),
    );
    _materials = LocalMaterialRepository(
      network: _network,
      usageCount: products.countByMaterial,
      store: _storeFor<FurnitureMaterial>(
        StorageKeys.materials,
        'Материалы',
        FurnitureMaterial.fromJson,
        (m) => m.toJson(),
      ),
    );
    _customers = LocalCustomerRepository(
      network: _network,
      store: _storeFor<Customer>(
        StorageKeys.customers,
        'Покупатели',
        Customer.fromJson,
        (c) => c.toJson(),
      ),
    );
    _products = products;

    final localDio = buildDio(baseUrl: AppConfig.apiBaseUrl);
    _authApi = AuthApi(localDio);
    _auth = AuthNotifier(widget.prefs, _authApi);

    _debug = DebugSettingsNotifier(simulator: _network);
    _refs = ReferenceDataNotifier(
      _categories,
      _manufacturers,
      _materials,
      maxAge: Duration.zero,
    );
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    _refs.dispose();
    _debug.dispose();
    if (_ready) _router.dispose();
    _auth.dispose();
    super.dispose();
  }

  Future<void> _onInactivityTimeout() async {
    await _auth.logout();
    _messenger.currentState?.clearSnackBars();
    _messenger.currentState?.showSnackBar(
      const SnackBar(
        content: Text('Сессия завершена из‑за неактивности.'),
        duration: Duration(seconds: 5),
      ),
    );
  }

  void _onInactivityWarning() {
    _messenger.currentState?.showSnackBar(
      const SnackBar(
        content: Text(
          'Выход через 30 секунд из‑за отсутствия действий. '
          'Двигайте мышь или нажмите клавишу, чтобы остаться.',
        ),
        duration: Duration(seconds: 30),
      ),
    );
  }

  void _onInactivityWarningCancel() {
    _messenger.currentState?.hideCurrentSnackBar();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const MaterialApp(
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthNotifier>.value(value: _auth),
        Provider<AuthApi>.value(value: _authApi),
        Provider<ProductRepository>.value(value: _products),
        Provider<ManufacturerRepository>.value(value: _manufacturers),
        Provider<CategoryRepository>.value(value: _categories),
        Provider<MaterialRepository>.value(value: _materials),
        Provider<CustomerRepository>.value(value: _customers),
        Provider<OrderRepository?>.value(value: _orders),
        Provider<UnsavedChangesGuard>.value(value: _guard),
        ChangeNotifierProvider(create: (_) => ProductListNotifier(_products)),
        ChangeNotifierProvider(
          create: (_) => ManufacturerListNotifier(_manufacturers),
        ),
        ChangeNotifierProvider(
          create: (_) => CategoryListNotifier(_categories),
        ),
        ChangeNotifierProvider(create: (_) => MaterialListNotifier(_materials)),
        ChangeNotifierProvider(create: (_) => CustomerListNotifier(_customers)),
        ChangeNotifierProvider.value(value: _refs..load()),
        ChangeNotifierProvider.value(value: _debug),
      ],
      child: Consumer<AuthNotifier>(
        builder: (context, auth, child) {
          return InactivityWatcher(
            enabled: AppConfig.useApi && auth.isAuthenticated,
            timeout: AuthNotifier.inactivityTimeout,
            warningBefore: AuthNotifier.inactivityWarning,
            onTimeout: _onInactivityTimeout,
            onWarning: _onInactivityWarning,
            onWarningCancel: _onInactivityWarningCancel,
            onActivity: () {
              auth.touchActivity();
            },
            child: child!,
          );
        },
        child: MaterialApp.router(
          title: 'МебельДом',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(useMaterial3: true),
          routerConfig: _router,
          scaffoldMessengerKey: _messenger,
          scrollBehavior: const AppScrollBehavior(),
          locale: const Locale('ru'),
          supportedLocales: const [Locale('ru')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
        ),
      ),
    );
  }
}
