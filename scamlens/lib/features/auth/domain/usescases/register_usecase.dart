import 'package:scamlens/features/auth/domain/entities/user_entity.dart';
import 'package:scamlens/features/auth/domain/repositories/auth_repository.dart';

class RegisterUseCase {
  final AuthRepository repository;

  RegisterUseCase({required this.repository});
  Future<UserEntity> call({
    required String name,
    required String lastName,
    required String email,
    required String password,
  }) {
    return repository.register(
      name: name,
      lastName: lastName,
      email: email,
      password: password,
    );
  }
}
