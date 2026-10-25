import 'package:scamlens/features/auth/domain/entities/profile.dart';
import 'package:scamlens/features/auth/domain/repositories/auth_repository.dart';
import 'package:scamlens/features/auth/domain/repositories/profile_repository.dart';

class RegisterUseCase {
  final AuthRepository authRepository;
  final ProfileRepository profileRepository;

  RegisterUseCase({
    required this.authRepository,
    required this.profileRepository,
  });

  Future<Profile> call({
    required String name,
    required String lastName,
    required String email,
    required String password,
  }) async {
    final authUser = await authRepository.signUp(
      email: email,
      password: password,
    );

    final profile = Profile(
      id: authUser.id,
      name: name,
      lastName: lastName,
      email: authUser.email,
      active: true,
      createdIn: DateTime.now().toUtc(),
    );

    await profileRepository.createProfile(profile);

    return profile;
  }
}
