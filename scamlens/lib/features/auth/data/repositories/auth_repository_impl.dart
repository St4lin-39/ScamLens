import 'package:scamlens/features/auth/data/datasources/supabase_auth_datasource.dart';
import 'package:scamlens/features/auth/domain/entities/user_entity.dart';
import 'package:scamlens/features/auth/domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  final SupabaseAuthDatasource datasource;

  AuthRepositoryImpl(this.datasource);
  @override
  Future<UserEntity> signUp({required String email, required String password}) {
    return datasource.signUp(email: email, password: password);
  }

  @override
  Future<UserEntity> signIn({required String email, required String password}) {
    return datasource.signIn(email: email, password: password);
  }

  @override
  Future<void> signOut() {
    return datasource.signOut();
  }
}
