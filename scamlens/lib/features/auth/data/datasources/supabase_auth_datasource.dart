import 'package:scamlens/features/auth/domain/entities/auth_user.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;

class SupabaseAuthDatasource {
  final SupabaseClient client;

  SupabaseAuthDatasource({required this.client});

  Future<AuthUser> signUp({
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

    return AuthUser(id: user.id, email: user.email ?? email);
  }

  Future<AuthUser> signIn({
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
    return AuthUser(id: user.id, email: user.email ?? email);
  }

  Future<void> signOut() async {
    await client.auth.signOut();
  }
}
