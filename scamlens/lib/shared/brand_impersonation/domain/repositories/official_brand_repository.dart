import '../entities/official_brand.dart';
import '../entities/official_brand_catalog.dart';

/// Optional richer contract; existing repository implementations remain valid.
abstract class OfficialBrandCatalogReader {
  Future<OfficialBrandCatalog> getCatalogSnapshot();
}

abstract class OfficialBrandRepository {
  Future<List<OfficialBrand>> getActiveBrands();

  void invalidateCache();
}
