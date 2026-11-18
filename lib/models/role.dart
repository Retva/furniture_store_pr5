/// Роли учебного приложения «МебельДом».
///
/// Уровень сравнивается числом: более высокая роль включает права нижестоящих
/// для операций «начиная с …». Незнакомый код с сервера трактуется как
/// [viewer] — опечатка не должна выдавать права администратора.
enum Role {
  viewer(1, 'viewer', 'Покупатель'),
  manager(2, 'manager', 'Менеджер'),
  admin(3, 'admin', 'Администратор');

  const Role(this.level, this.code, this.label);

  final int level;
  final String code;
  final String label;

  static Role fromCode(String? code) {
    return Role.values.firstWhere(
      (r) => r.code == code,
      orElse: () => Role.viewer,
    );
  }

  bool atLeast(Role other) => level >= other.level;
}
