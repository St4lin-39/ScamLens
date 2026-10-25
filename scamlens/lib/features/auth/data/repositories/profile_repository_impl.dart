import 'package:scamlens/features/auth/data/datasources/supabase_profile_datasource.dart';
import 'package:scamlens/features/auth/domain/entities/profile.dart';
import 'package:scamlens/features/auth/domain/repositories/profile_repository.dart';

/// Implementa el contrato ProfileRepository usando SupabaseProfileDatasource.
class ProfileRepositoryImpl implements ProfileRepository {
  final SupabaseProfileDatasource datasource;

  ProfileRepositoryImpl(this.datasource);

  @override
  Future<void> createProfile(Profile profile) {
    return datasource.createProfile(profile);
  }

  @override
  Future<Profile> getProfile(String id) {
    return datasource.getProfile(id);
  }
}
