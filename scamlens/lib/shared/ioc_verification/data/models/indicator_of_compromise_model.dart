import '../../domain/entities/indicator_of_compromise.dart';

class IndicatorOfCompromiseModel extends IndicatorOfCompromise {
  const IndicatorOfCompromiseModel({
    required super.id,
    required super.type,
    required super.value,
    required super.attackType,
    required super.detectionSource,
    required super.active,
    required super.createdIn,
  });

  factory IndicatorOfCompromiseModel.fromJson(Map<String, dynamic> json) {
    final parsedType = IocType.fromCode(json['type'] as String);
    final rawValue = (json['value'] as String).trim();
    return IndicatorOfCompromiseModel(
      id: json['id'] as String,
      type: parsedType,
      value: parsedType == IocType.url ? rawValue : rawValue.toLowerCase(),
      attackType: (json['attack_type'] as String).trim(),
      detectionSource: (json['detection_source'] as String).trim(),
      active: (json['active'] as bool?) ?? true,
      createdIn: json['created_in'] != null
          ? DateTime.parse(json['created_in'] as String)
          : DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }
}
