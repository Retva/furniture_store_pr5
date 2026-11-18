import 'package:flutter/material.dart';

/// Кнопки действий над записью в строке таблицы или в карточке.
/// Флаги видимости задаёт вызывающий код по роли — это уборка UI, не защита.
List<Widget> recordActions({
  required bool isDeleted,
  required VoidCallback onEdit,
  required VoidCallback onSoftDelete,
  required VoidCallback onRestore,
  required VoidCallback onHardDelete,
  bool busy = false,
  bool canEdit = true,
  bool canSoftDelete = true,
  bool canRestore = true,
  bool canHardDelete = true,
}) {
  VoidCallback? unlessBusy(VoidCallback action) => busy ? null : action;
  return [
    if (!isDeleted) ...[
      if (canEdit)
        IconButton(
          tooltip: 'Изменить',
          icon: const Icon(Icons.edit_outlined),
          onPressed: unlessBusy(onEdit),
        ),
      if (canSoftDelete)
        IconButton(
          tooltip: 'Удалить (можно восстановить)',
          icon: const Icon(Icons.delete_outline),
          onPressed: unlessBusy(onSoftDelete),
        ),
    ] else ...[
      if (canRestore)
        IconButton(
          tooltip: 'Восстановить',
          icon: const Icon(Icons.restore_from_trash_outlined),
          onPressed: unlessBusy(onRestore),
        ),
      if (canHardDelete)
        IconButton(
          tooltip: 'Удалить навсегда',
          icon: const Icon(Icons.delete_forever_outlined),
          onPressed: unlessBusy(onHardDelete),
        ),
    ],
  ];
}
