/// Representa los datos de perfil del usuario dentro de ScamLens,
/// separados de la identidad de autenticación.
class Profile {
  final String id;
  final String name;
  final String lastName;
  final String email;
  final bool active;
  final DateTime createdIn;

  const Profile({
    required this.id,
    required this.name,
    required this.lastName,
    required this.email,
    required this.active,
    required this.createdIn,
  });

  String get fullName => '$name $lastName'.trim();
}
