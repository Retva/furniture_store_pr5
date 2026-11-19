import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api_exception.dart';
import '../api/auth_api.dart';
import '../state/auth_notifier.dart';
import '../core/formatting.dart';
import '../widgets/state_views.dart';

/// Личные заказы покупателя — экран только для роли viewer.
class MyOrdersScreen extends StatefulWidget {
  const MyOrdersScreen({super.key});

  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    final userId = context.read<AuthNotifier>().user!.id;
    _future = context.read<AuthApi>().myOrders(userId);
  }

  void _reload() {
    final userId = context.read<AuthNotifier>().user!.id;
    setState(() => _future = context.read<AuthApi>().myOrders(userId));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
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
                : 'Не удалось загрузить заказы',
            onRetry: _reload,
          );
        }
        final orders = snapshot.data ?? const [];
        if (orders.isEmpty) {
          return const EmptyView(
            title: 'Заказов пока нет',
            message:
                'Это личный раздел покупателя. Менеджер и администратор '
                'сюда не попадают — у них другие экраны.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: orders.length + 1,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            if (index == 0) {
              return Text(
                'Мои заказы',
                style: Theme.of(context).textTheme.titleLarge,
              );
            }
            final order = orders[index - 1];
            final product = order['product'];
            final name = product is Map
                ? '${product['name']}'
                : 'Заказ №${order['id']}';
            final total = order['total'];
            final cancelled = order['cancelledAt'] != null;
            return Card(
              child: ListTile(
                title: Text(name),
                subtitle: Text(
                  cancelled
                      ? 'Отменён'
                      : 'Сумма: ${total is num ? formatPrice(total.toInt()) : total}',
                ),
                trailing: Text('×${order['quantity'] ?? 1}'),
              ),
            );
          },
        );
      },
    );
  }
}
