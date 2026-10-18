import 'package:scamlens/features/auth/domain/entities/user_entity.dart';

class UserModel extends UserEntity {
  const UserModel({
    required super.id,
    required super.name,
    required super.lastName,
    required super.email,
    required super.active,
    required super.createdIn,
  });
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      name: (json['name'] ?? '') as String,
      lastName: (json['lastName'] ?? '') as String,
      email: (json['email'] ?? '') as String,
      active: (json['active'] ?? true) as bool,
      createdIn: json['createdIn'] != null
          ? DateTime.parse(json['createdIn'] as String)
          : DateTime.now(),
    );
  }
}
