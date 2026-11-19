import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../state/auth_notifier.dart';

class ForbiddenScreen extends StatelessWidget {
  const ForbiddenScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = context.watch<AuthNotifier>();
    final tampered = auth.roleTampered;
    final stored = auth.storedRole;
    final real = auth.user?.role;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.lock_outline,
                size: 64,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Недостаточно прав',
                style: theme.textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                tampered
                    ? 'Роль в localStorage (${stored?.code ?? '—'}) не совпадает '
                          'с ролью на сервере (${real?.code ?? '—'}). '
                          'Подмена на клиенте не выдаёт права — решение принимает сервер.'
                    : 'Этот раздел недоступен вашей роли. '
                          'Клиентская проверка лишь скрывает недоступное; '
                          'решение о доступе принимает сервер.',
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              if (tampered)
                FilledButton(
                  onPressed: () async {
                    await auth.restoreStoredRole();
                    if (context.mounted) context.go('/');
                  },
                  child: const Text('Восстановить роль'),
                )
              else
                FilledButton(
                  onPressed: () => context.go('/'),
                  child: const Text('На главную'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
