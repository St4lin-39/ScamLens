import 'package:scamlens/features/auth/domain/entities/profile.dart';
import 'package:scamlens/features/auth/domain/repositories/auth_repository.dart';
import 'package:scamlens/features/auth/domain/repositories/profile_repository.dart';

class LoginUseCase {
  final AuthRepository authRepository;
  final ProfileRepository profileRepository;

  LoginUseCase({
    required this.authRepository,
    required this.profileRepository,
  });

  Future<Profile> call({required String email, required String password}) async {
    final authUser = await authRepository.signIn(
      email: email,
      password: password,
    );
    return profileRepository.getProfile(authUser.id);
  }
}
