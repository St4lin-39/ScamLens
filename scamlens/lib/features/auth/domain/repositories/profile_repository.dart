import 'package:scamlens/features/auth/domain/entities/profile.dart';

/// Define las operaciones disponibles para gestionar el perfil del usuario,
/// sin conocer cómo se almacenan los datos.
abstract class ProfileRepository {
  Future<void> createProfile(Profile profile);

  Future<Profile> getProfile(String id);
}
