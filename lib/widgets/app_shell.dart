import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../api/debug_options.dart';
import '../core/breakpoints.dart';
import '../core/config.dart';
import '../models/role.dart';
import '../state/auth_notifier.dart';
import '../state/debug_settings_notifier.dart';

/// Общий каркас: шапка с именем пользователя, меню по ролям.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  static const List<_Section> _allSections = [
    _Section('Каталог', '/products', Icons.chair_outlined, Icons.chair),
    _Section(
      'Производители',
      '/manufacturers',
      Icons.factory_outlined,
      Icons.factory,
    ),
    _Section(
      'Категории',
      '/categories',
      Icons.category_outlined,
      Icons.category,
    ),
    _Section('Материалы', '/materials', Icons.texture_outlined, Icons.texture),
    _Section('Покупатели', '/customers', Icons.people_outline, Icons.people),
    _Section(
      'Мои заказы',
      '/my-orders',
      Icons.receipt_long_outlined,
      Icons.receipt_long,
    ),
    _Section(
      'Пользователи',
      '/admin/users',
      Icons.manage_accounts_outlined,
      Icons.manage_accounts,
    ),
    _Section(
      'Статистика',
      '/admin/stats',
      Icons.bar_chart_outlined,
      Icons.bar_chart,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();
    final perms = auth.permissions;
    final sections = [
      for (final s in _allSections)
        if (perms.canSeeNav(s.path)) s,
    ];

    final path = GoRouterState.of(context).uri.path;
    final selected = _sectionIndex(path, sections);
    final compact = screenSizeOf(context) == ScreenSize.compact;

    void onSelect(int index) => context.go(sections[index].path);

    final appBar = AppBar(
      title: Text(_titleFor(path)),
      actions: [
        if (auth.user != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Center(
              child: Text(
                '${auth.user!.fullName} · ${auth.user!.role.label}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ),
        IconButton(
          tooltip: 'Выйти',
          onPressed: () async {
            await auth.logout();
            if (context.mounted) context.go('/login');
          },
          icon: const Icon(Icons.logout),
        ),
        const _DebugMenu(),
        const SizedBox(width: 8),
      ],
    );

    if (sections.isEmpty) {
      return Scaffold(appBar: appBar, body: child);
    }

    if (compact) {
      return Scaffold(
        appBar: appBar,
        body: child,
        bottomNavigationBar: NavigationBar(
          selectedIndex: selected ?? 0,
          onDestinationSelected: onSelect,
          destinations: [
            for (final s in sections)
              NavigationDestination(
                icon: Icon(s.icon),
                selectedIcon: Icon(s.selectedIcon),
                label: s.title,
              ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: appBar,
      body: Row(
        children: [
          NavigationRail(
            extended: true,
            minExtendedWidth: 200,
            selectedIndex: selected,
            onDestinationSelected: onSelect,
            destinations: [
              for (final s in sections)
                NavigationRailDestination(
                  icon: Icon(s.icon),
                  selectedIcon: Icon(s.selectedIcon),
                  label: Text(s.title),
                ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: child),
        ],
      ),
    );
  }

  static int? _sectionIndex(String location, List<_Section> sections) {
    for (var i = 0; i < sections.length; i++) {
      final path = sections[i].path;
      if (location == path || location.startsWith('$path/')) return i;
    }
    return null;
  }

  static const Map<String, (String, String)> _titles = {
    '/products': ('Каталог мебели', 'товара'),
    '/manufacturers': ('Производители', 'производителя'),
    '/categories': ('Категории', 'категории'),
    '/materials': ('Материалы', 'материала'),
    '/customers': ('Покупатели', 'покупателя'),
    '/my-orders': ('Мои заказы', 'заказа'),
    '/admin/users': ('Пользователи', 'пользователя'),
    '/admin/stats': ('Статистика', 'статистики'),
  };

  static String _titleFor(String path) {
    if (path == '/forbidden') return 'Отказ в доступе';
    for (final MapEntry(key: base, value: (list, of)) in _titles.entries) {
      if (path == base) return list;
      if (path == '$base/new') return 'Создание $of';
      if (path.startsWith('$base/') && path.endsWith('/edit')) {
        return 'Изменение $of';
      }
      if (path.startsWith('$base/')) return 'Карточка $of';
    }
    return 'МебельДом — мебельный магазин';
  }
}

class _Section {
  const _Section(this.title, this.path, this.icon, this.selectedIcon);

  final String title;
  final String path;
  final IconData icon;
  final IconData selectedIcon;
}

class _DebugMenu extends StatelessWidget {
  const _DebugMenu();

  @override
  Widget build(BuildContext context) {
    final debug = context.watch<DebugSettingsNotifier>();
    final active = debug.slowResponses || debug.failResponses;

    return PopupMenuButton<String>(
      tooltip: 'Отладка',
      icon: Badge(
        isLabelVisible: active,
        smallSize: 8,
        child: const Icon(Icons.bug_report_outlined),
      ),
      onSelected: (value) => switch (value) {
        'slow' => debug.toggleSlow(),
        'fail' => debug.toggleFail(),
        _ => null,
      },
      itemBuilder: (context) => [
        if (debug.usesApi) ...[
          const PopupMenuItem<String>(
            enabled: false,
            child: Text('Сервер: ${AppConfig.apiBaseUrl}'),
          ),
          PopupMenuItem<String>(
            enabled: false,
            child: Text(
              'Роль: ${context.read<AuthNotifier>().user?.role.label ?? '—'}',
            ),
          ),
          const PopupMenuDivider(),
          CheckedPopupMenuItem<String>(
            value: 'slow',
            checked: debug.slowResponses,
            child: const Text(
              'Медленные ответы (__delay=${DebugOptions.delayMs})',
            ),
          ),
          CheckedPopupMenuItem<String>(
            value: 'fail',
            checked: debug.failResponses,
            child: const Text(
              'Ошибка сервера (__fail=${DebugOptions.failStatus})',
            ),
          ),
          const PopupMenuDivider(),
          const PopupMenuItem<String>(
            enabled: false,
            child: Text('Для смены роли войдите под другой учёткой'),
          ),
          for (final role in Role.values)
            PopupMenuItem<String>(
              enabled: false,
              child: Text('  ${role.code}: см. экран входа'),
            ),
        ] else
          CheckedPopupMenuItem<String>(
            value: 'fail',
            checked: debug.failResponses,
            child: const Text('Имитировать сбой сети'),
          ),
      ],
    );
  }
}
