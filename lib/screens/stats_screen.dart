import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api_exception.dart';
import '../api/auth_api.dart';
import '../widgets/state_views.dart';

/// Сводная статистика магазина — экран только для администратора.
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  late Future<Map<String, int>> _future;

  static const _labels = {
    'products': 'Товары',
    'manufacturers': 'Производители',
    'categories': 'Категории',
    'materials': 'Материалы',
    'customers': 'Покупатели',
    'orders': 'Открытые заказы',
    'users': 'Пользователи',
  };

  @override
  void initState() {
    super.initState();
    _future = context.read<AuthApi>().stats();
  }

  void _reload() {
    setState(() => _future = context.read<AuthApi>().stats());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, int>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const LoadingView();
        }
        if (snapshot.hasError) {
          final error = snapshot.error;
          return ErrorView(
            message: error is ApiException
                ? error.message
                : 'Не удалось загрузить статистику',
            onRetry: _reload,
          );
        }
        final stats = snapshot.data ?? {};
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Статистика магазина',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Раздел недоступен менеджеру и покупателю — '
              'сервер ответит 403 при прямом запросе.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final entry in _labels.entries)
                  SizedBox(
                    width: 180,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.value,
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${stats[entry.key] ?? 0}',
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}
