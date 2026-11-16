import 'official_brand.dart';

enum BrandCatalogStatus { available, stale, unavailable, unknown }

/// A successful empty catalog is available, unlike a failed request.
class OfficialBrandCatalog {
  final List<OfficialBrand> brands;
  final BrandCatalogStatus status;

  OfficialBrandCatalog({
    required Iterable<OfficialBrand> brands,
    required this.status,
  }) : brands = List.unmodifiable(brands);
}
