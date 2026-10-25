import 'package:scamlens/features/auth/domain/entities/profile.dart';

/// Transforma los datos de public.user a la entidad Profile del dominio.
class ProfileModel extends Profile {
  const ProfileModel({
    required super.id,
    required super.name,
    required super.lastName,
    required super.email,
    required super.active,
    required super.createdIn,
  });

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      id: json['id'] as String,
      name: json['name'] as String,
      lastName: json['last_name'] as String,
      email: json['email'] as String,
      active: json['active'] as bool,
      createdIn: DateTime.parse(json['created_in'] as String),
    );
  }
}
