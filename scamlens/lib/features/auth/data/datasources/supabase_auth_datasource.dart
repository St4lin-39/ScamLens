import 'package:scamlens/features/auth/domain/entities/user_entity.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseAuthDatasource {
  final SupabaseClient client;

  SupabaseAuthDatasource({required this.client});

  Future<UserEntity> signUp({
    required String email,
    required String password,
  }) async {
    final AuthResponse response = await client.auth.signUp(
      email: email,
      password: password,
    );

    final user = response.user;
    if (user == null) {
      throw Exception('User registration failed.');
    }

    return UserEntity(id: user.id, email: user.email ?? email);
  }

  Future<UserEntity> signIn({
    required String email,
    required String password,
  }) async {
    final AuthResponse response = await client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    final user = response.user;
    if (user == null) {
      throw Exception('Invalid credentials');
    }
    return UserEntity(id: user.id, email: user.email ?? email);
  }

  Future<void> signOut() async {
    await client.auth.signOut();
  }
}
