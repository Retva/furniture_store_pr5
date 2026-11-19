import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api_exception.dart';
import '../api/auth_api.dart';
import '../models/app_user.dart';
import '../models/role.dart';
import '../widgets/state_views.dart';

/// Управление пользователями и ролями — экран только для администратора.
class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  late Future<List<AppUser>> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<AuthApi>().listUsers();
  }

  void _reload() {
    setState(() => _future = context.read<AuthApi>().listUsers());
  }

  Future<void> _changeRole(AppUser user, Role role) async {
    try {
      await context.read<AuthApi>().updateUserRole(
        user.id,
        RoleUpdate(role: role.code),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Роль «${user.username}» → ${role.label}')),
      );
      _reload();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<AppUser>>(
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
                : 'Не удалось загрузить пользователей',
            onRetry: _reload,
          );
        }
        final users = snapshot.data ?? const [];
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Пользователи и роли',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Только администратор может менять роли. '
              'Сервер отклонит попытку без прав с кодом 403.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            for (final user in users)
              Card(
                child: ListTile(
                  title: Text(user.fullName),
                  subtitle: Text('${user.username} · ${user.role.label}'),
                  trailing: DropdownButton<Role>(
                    value: user.role,
                    items: [
                      for (final role in Role.values)
                        DropdownMenuItem(value: role, child: Text(role.label)),
                    ],
                    onChanged: (role) {
                      if (role != null && role != user.role) {
                        _changeRole(user, role);
                      }
                    },
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
