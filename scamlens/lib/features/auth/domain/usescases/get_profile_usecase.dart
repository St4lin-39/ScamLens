import 'package:scamlens/features/auth/domain/entities/user_entity.dart';
import 'package:scamlens/features/auth/domain/repositories/auth_repository.dart';

class GetProfileUseCase {
  final AuthRepository repository;

  GetProfileUseCase(this.repository);

  Future<UserEntity> call() {
    return repository.getCurrentProfile();
  }
}
