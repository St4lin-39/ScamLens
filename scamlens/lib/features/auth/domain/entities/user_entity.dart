class UserEntity {
  final String id;
  final String name;
  final String lastName;
  final String email;
  final bool active;
  final DateTime createdIn;

  const UserEntity({
    required this.id,
    required this.name,
    required this.lastName,
    required this.email,
    required this.active,
    required this.createdIn,
  });
  String get fullName => '$name $lastName'.trim();
}
