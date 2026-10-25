/// Representa la identidad autenticada y contiene únicamente la información
/// de autenticación necesaria para la capa de dominio.
class AuthUser {
  final String id;
  final String email;

  const AuthUser({
    required this.id,
    required this.email,
  });
}
