import 'package:scamlens/features/auth/domain/entities/profile.dart';
import 'package:scamlens/features/auth/domain/repositories/auth_repository.dart';
import 'package:scamlens/features/auth/domain/repositories/profile_repository.dart';

class GetProfileUseCase {
  final ProfileRepository repository;
  final AuthRepository authRepository;

  GetProfileUseCase(this.repository, this.authRepository);

  Future<Profile> call([String? id]) async {
    final userId = id ?? authRepository.getCurrentUserId();
    if (userId == null) {
      throw Exception('No hay usuario autenticado');
    }
    return repository.getProfile(userId);
  }
}
