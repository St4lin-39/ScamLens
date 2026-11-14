import '../../domain/entities/official_brand.dart';
import '../../domain/repositories/official_brand_repository.dart';
import '../datasources/supabase_official_brand_datasource.dart';

class OfficialBrandRepositoryImpl implements OfficialBrandRepository {
  final SupabaseOfficialBrandDatasource datasource;
  final Duration cacheTtl;
  final DateTime Function() clock;

  List<OfficialBrand>? _cachedBrands;
  DateTime? _cacheExpiresAt;
  Future<List<OfficialBrand>>? _inFlight;

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
  Future<List<OfficialBrand>> getActiveBrands() {
    final now = clock();
    if (_cachedBrands != null &&
        _cacheExpiresAt != null &&
        now.isBefore(_cacheExpiresAt!)) {
      return Future.value(_cachedBrands!);
    }

    return _inFlight ??= _loadFromRemote().whenComplete(() {
      _inFlight = null;
    });
  }

  Future<List<OfficialBrand>> _loadFromRemote() async {
    try {
      final remote = await datasource.fetchActiveBrands();
      final frozen = List<OfficialBrand>.unmodifiable(remote);
      _cachedBrands = frozen;
      _cacheExpiresAt = clock().add(cacheTtl);
      return frozen;
    } catch (_) {
      return _cachedBrands ?? const <OfficialBrand>[];
    }
  }
}
