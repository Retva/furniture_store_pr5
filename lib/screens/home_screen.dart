import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../state/auth_notifier.dart';

/// Главная: короткое описание и переходы к доступным разделам.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = context.watch<AuthNotifier>();
    final perms = auth.permissions;
    final user = auth.user;

    final links = <(String, IconData, String)>[
      if (perms.canBrowseCatalog) ...[
        ('/products', Icons.chair_outlined, 'Каталог'),
        ('/manufacturers', Icons.factory_outlined, 'Производители'),
        ('/categories', Icons.category_outlined, 'Категории'),
        ('/materials', Icons.texture_outlined, 'Материалы'),
      ],
      if (perms.canManageCustomers)
        ('/customers', Icons.people_outline, 'Покупатели'),
      if (perms.canViewMyOrders)
        ('/my-orders', Icons.receipt_long_outlined, 'Мои заказы'),
      if (perms.canManageUsers)
        ('/admin/users', Icons.manage_accounts_outlined, 'Пользователи'),
      if (perms.canViewStats)
        ('/admin/stats', Icons.bar_chart_outlined, 'Статистика'),
    ];

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Сайт мебельного магазина «МебельДом»',
                style: theme.textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                user == null
                    ? 'Войдите, чтобы работать с каталогом.'
                    : 'Вы вошли как ${user.fullName} (${user.role.label}). '
                          'Доступные разделы зависят от роли.',
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  for (final (path, icon, label) in links)
                    FilledButton.icon(
                      onPressed: () => context.go(path),
                      icon: Icon(icon),
                      label: Text(label),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
