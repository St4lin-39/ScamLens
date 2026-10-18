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
  }
}
