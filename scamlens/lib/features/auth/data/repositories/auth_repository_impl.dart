import 'package:scamlens/features/auth/data/datasources/supabase_auth_datasource.dart';
import 'package:scamlens/features/auth/domain/entities/user_entity.dart';
import 'package:scamlens/features/auth/domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  final SupabaseAuthDatasource datasource;

  AuthRepositoryImpl(this.datasource);
  @override
  Future<UserEntity> register({
    required String name,
    required String lastName,
    required String email,
    required String password,
  }) {
    return datasource.register(
      name: name,
      lastName: lastName,
      email: email,
      password: password,
    );
  }

  @override
  Future<UserEntity> login({required String email, required String password}) {
    return datasource.login(email: email, password: password);
  }

  @override
  Future<UserEntity> getCurrentProfile() {
    return datasource.getCurrentProfile();
  }

  @override
  Future<void> signOut() {
    return datasource.signOut();
  }
}
