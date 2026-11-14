import '../entities/official_brand.dart';

abstract class OfficialBrandRepository {
  Future<List<OfficialBrand>> getActiveBrands();

  void invalidateCache();
}
