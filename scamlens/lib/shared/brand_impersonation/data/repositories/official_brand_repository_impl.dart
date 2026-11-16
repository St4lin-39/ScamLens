import '../../domain/entities/official_brand.dart';
import '../../domain/entities/official_brand_catalog.dart';
import '../../domain/repositories/official_brand_repository.dart';
import '../datasources/supabase_official_brand_datasource.dart';

class OfficialBrandRepositoryImpl
    implements OfficialBrandRepository, OfficialBrandCatalogReader {
  final SupabaseOfficialBrandDatasource datasource;
  final Duration cacheTtl;
  final DateTime Function() clock;

  List<OfficialBrand>? _cachedBrands;
  DateTime? _cacheExpiresAt;
  Future<OfficialBrandCatalog>? _inFlight;

  OfficialBrandRepositoryImpl({
    required this.datasource,
    this.cacheTtl = const Duration(minutes: 5),
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now;

  @override
  void invalidateCache() {
    _cachedBrands = null;
    _cacheExpiresAt = null;
  }

  @override
  Future<List<OfficialBrand>> getActiveBrands() async =>
      (await getCatalogSnapshot()).brands;

  @override
  Future<OfficialBrandCatalog> getCatalogSnapshot() {
    final now = clock();
    if (_cachedBrands != null &&
        _cacheExpiresAt != null &&
        now.isBefore(_cacheExpiresAt!)) {
      return Future.value(
        OfficialBrandCatalog(
          brands: _cachedBrands!,
          status: BrandCatalogStatus.available,
        ),
      );
    }

    return _inFlight ??= _loadFromRemote().whenComplete(() {
      _inFlight = null;
    });
  }

  Future<OfficialBrandCatalog> _loadFromRemote() async {
    try {
      final remote = await datasource.fetchActiveBrands();
      final frozen = List<OfficialBrand>.unmodifiable(remote);
      _cachedBrands = frozen;
      _cacheExpiresAt = clock().add(cacheTtl);
      return OfficialBrandCatalog(
        brands: frozen,
        status: BrandCatalogStatus.available,
      );
    } catch (_) {
      return OfficialBrandCatalog(
        brands: _cachedBrands ?? const <OfficialBrand>[],
        status: _cachedBrands == null
            ? BrandCatalogStatus.unavailable
            : BrandCatalogStatus.stale,
      );
    }
  }
}
