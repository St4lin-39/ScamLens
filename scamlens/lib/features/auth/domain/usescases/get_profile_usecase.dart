import 'package:scamlens/features/auth/domain/entities/profile.dart';
import 'package:scamlens/features/auth/domain/repositories/profile_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GetProfileUseCase {
  final ProfileRepository repository;

  GetProfileUseCase(this.repository);

  Future<Profile> call([String? id]) async {
    final userId = id ?? Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('No hay usuario autenticado');
    }
    return repository.getProfile(userId);
  }
}
