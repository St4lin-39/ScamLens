/// Representa la identidad autenticada y contiene únicamente la información
/// de autenticación necesaria para la capa de dominio.
class UserEntity {
  final String id;
  final String email;

  const UserEntity({required this.id, required this.email});
}
