class OfficialBrand {
  final String id;
  final String entityName;
  final String officialDomain;
  final String category;
  final bool active;
  final DateTime createdIn;

  const OfficialBrand({
    required this.id,
    required this.entityName,
    required this.officialDomain,
    required this.category,
    required this.active,
    required this.createdIn,
  });
}
