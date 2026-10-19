import 'package:scamlens/features/auth/data/models/user_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseAuthDatasource {
  final SupabaseClient client;

  SupabaseAuthDatasource({required this.client});

  Future<UserModel> register({
    required String name,
    required String lastName,
    required String email,
    required String password,
  }) async {
    final AuthResponse response = await client.auth.signUp(
      email: email,
      password: password,
      data: {'name': name, 'lastName': lastName},
    );

    final user = response.user;
    if (user == null) {
      throw Exception('User registration failed.');
    }

    return UserModel.fromJson(user.toJson());
  }

  Future<UserModel> login({
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
    return getCurrentProfile();
  }

  Future<UserModel> getCurrentProfile() async {
    final currentUser = client.auth.currentUser;
    if (currentUser == null) {
      throw Exception('There isnt an active session');
    }

    final data = await client
        .from('user')
        .select()
        .eq('id', currentUser.id)
        .single();
    return UserModel.fromJson(data);
  }

  Future<void> signOut() async {
    await client.auth.signOut();
  }
}
