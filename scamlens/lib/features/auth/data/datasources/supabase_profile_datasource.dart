import 'package:scamlens/features/auth/data/models/profile_model.dart';
import 'package:scamlens/features/auth/domain/entities/profile.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Contiene las operaciones de Supabase relacionadas con los perfiles de ScamLens.
class SupabaseProfileDatasource {
  final SupabaseClient client;

  SupabaseProfileDatasource({required this.client});

  Future<void> createProfile(Profile profile) async {
    await client.from('user').insert({
      'id': profile.id,
      'name': profile.name,
      'last_name': profile.lastName,
      'email': profile.email,
      'active': profile.active,
      'created_in': profile.createdIn.toIso8601String(),
    });
  }

  Future<ProfileModel> getProfile(String id) async {
    final data = await client
        .from('user')
        .select()
        .eq('id', id)
        .single();
    return ProfileModel.fromJson(data);
  }
}
