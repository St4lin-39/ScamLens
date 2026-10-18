import 'package:scamlens/features/auth/domain/entities/user_entity.dart';

abstract class AuthRepository {
  Future<UserEntity> register({
    required String name,
    required String lastName,
    required String email,
    required String password,
  });
  Future<UserEntity> login({required String email, required String password});
  Future<UserEntity> getCurrentProfile();
  Future<void> signOut();
}
