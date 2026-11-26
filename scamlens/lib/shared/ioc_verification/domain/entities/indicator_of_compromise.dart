enum IocType {
  url,
  domain,
  ip;

  static IocType fromCode(String raw) => switch (raw.trim().toUpperCase()) {
    'URL' => IocType.url,
    'DOMAIN' => IocType.domain,
    'IP' => IocType.ip,
    _ => throw FormatException('Unsupported IOC type: $raw'),
  };

  String get dbCode => switch (this) {
    IocType.url => 'URL',
    IocType.domain => 'DOMAIN',
    IocType.ip => 'IP',
  };
}

class IndicatorOfCompromise {
  final String id;
  final IocType type;
  final String value;
  final String attackType;
  final String detectionSource;
  final bool active;
  final DateTime createdIn;

  const IndicatorOfCompromise({
    required this.id,
    required this.type,
    required this.value,
    required this.attackType,
    required this.detectionSource,
    required this.active,
    required this.createdIn,
  });
}
