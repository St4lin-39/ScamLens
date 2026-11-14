import '../../domain/entities/official_brand.dart';

class OfficialBrandModel extends OfficialBrand {
  const OfficialBrandModel({
    required super.id,
    required super.entityName,
    required super.officialDomain,
    required super.category,
    required super.active,
    required super.createdIn,
  });

  factory OfficialBrandModel.fromJson(Map<String, dynamic> json) {
    return OfficialBrandModel(
      id: json['id'] as String,
      entityName: json['entity_name'] as String,
      officialDomain: (json['official_domain'] as String).trim().toLowerCase(),
      category: json['category'] as String,
      active: (json['active'] as bool?) ?? true,
      createdIn: json['created_in'] != null
          ? DateTime.parse(json['created_in'] as String)
          : DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }
}
