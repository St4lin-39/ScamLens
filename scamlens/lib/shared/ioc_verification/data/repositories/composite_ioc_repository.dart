import '../../domain/entities/indicator_of_compromise.dart';
import '../../domain/entities/ioc_check_result.dart';
import '../../domain/repositories/ioc_repository.dart';
import '../datasources/google_safe_browsing_datasource.dart';
import '../datasources/supabase_ioc_datasource.dart';

class _CachedIocEntry {
  final IocCheckResult result;
  final DateTime expiresAt;

  const _CachedIocEntry({required this.result, required this.expiresAt});
}

class CompositeIocRepository implements IocRepository {
  final SupabaseIocDatasource? supabaseDatasource;
  final GoogleSafeBrowsingDatasource? safeBrowsingDatasource;
  final Duration cacheTtl;
  final DateTime Function() clock;

  final Map<String, _CachedIocEntry> _cache = {};
  final Map<String, Future<IocCheckResult>> _inFlight = {};

  CompositeIocRepository({
    this.supabaseDatasource,
    this.safeBrowsingDatasource,
    this.cacheTtl = const Duration(minutes: 5),
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now;

  @override
  void invalidateCache() {
    _cache.clear();
  }

  @override
  Future<IocCheckResult> checkCandidates(IocCandidateSet candidates) {
    if (candidates.isEmpty) {
      return Future.value(
        const IocCheckResult(
          status: IocCheckStatus.notApplicable,
          sourceAvailability: IocSourceAvailability.available,
        ),
      );
    }

    final key = _buildCacheKey(candidates);
    final now = clock();
    final cached = _cache[key];
    if (cached != null && now.isBefore(cached.expiresAt)) {
      return Future.value(cached.result);
    }

    return _inFlight.putIfAbsent(
      key,
      () => _evaluateSources(candidates, key).whenComplete(() {
        _inFlight.remove(key);
      }),
    );
  }

  Future<IocCheckResult> _evaluateSources(
    IocCandidateSet candidates,
    String cacheKey,
  ) async {
    var configuredSources = 0;
    var succeededSources = 0;

    // 1. Primary fast lookup: Supabase public.indicator_of_compromise
    if (supabaseDatasource != null) {
      configuredSources++;
      try {
        final rows = await supabaseDatasource!.findActiveMatches(
          candidates.allLocalValues,
        );
        succeededSources++;

        final matchedRow = _selectTypedMatch(rows, candidates);
        if (matchedRow != null) {
          final hit = IocCheckResult(
            status: IocCheckStatus.matched,
            sourceAvailability: IocSourceAvailability.available,
            matchedIoc: matchedRow,
            matchedCandidate: matchedRow.value,
          );
          _storeCache(cacheKey, hit);
          return hit;
        }
      } catch (_) {
        // Degrade gracefully and continue to secondary source if configured
      }
    }

    // 2. Secondary live lookup: Google Safe Browsing API
    final gsb = safeBrowsingDatasource;
    if (gsb != null && gsb.isConfigured && candidates.remoteLookupUrls.isNotEmpty) {
      configuredSources++;
      try {
        final remoteHit = await gsb.lookupUrls(candidates.remoteLookupUrls);
        succeededSources++;

        if (remoteHit != null) {
          final availability = succeededSources == configuredSources
              ? IocSourceAvailability.available
              : IocSourceAvailability.partial;
          final hit = IocCheckResult(
            status: IocCheckStatus.matched,
            sourceAvailability: availability,
            matchedIoc: remoteHit,
            matchedCandidate: remoteHit.value,
          );
          _storeCache(cacheKey, hit);
          return hit;
        }
      } catch (_) {
        // Degrade gracefully; availability will reflect partial/unavailable
      }
    }

    final availability = configuredSources == 0
        ? IocSourceAvailability.notConfigured
        : succeededSources == configuredSources
        ? IocSourceAvailability.available
        : succeededSources > 0
        ? IocSourceAvailability.partial
        : IocSourceAvailability.unavailable;

    final cleanResult = IocCheckResult(
      status: IocCheckStatus.clean,
      sourceAvailability: availability,
    );

    if (availability == IocSourceAvailability.available) {
      _storeCache(cacheKey, cleanResult);
    }

    return cleanResult;
  }

  IndicatorOfCompromise? _selectTypedMatch(
    List<IndicatorOfCompromise> rows,
    IocCandidateSet candidates,
  ) {
    for (final row in rows) {
      if (!row.active) continue;
      final matches = switch (row.type) {
        IocType.ip => candidates.ips.contains(row.value.toLowerCase()),
        IocType.domain => candidates.domains.contains(row.value.toLowerCase()),
        IocType.url => candidates.urls.contains(row.value.trim()),
      };
      if (matches) return row;
    }
    return null;
  }

  void _storeCache(String key, IocCheckResult result) {
    _cache[key] = _CachedIocEntry(
      result: result,
      expiresAt: clock().add(cacheTtl),
    );
  }

  String _buildCacheKey(IocCandidateSet candidates) {
    final parts = <String>[
      ...(candidates.ips.toList()..sort()).map((v) => 'ip:$v'),
      ...(candidates.domains.toList()..sort()).map((v) => 'dom:$v'),
      ...(candidates.urls.toList()..sort()).map((v) => 'url:$v'),
      ...(candidates.remoteLookupUrls.toList()..sort()).map((v) => 'rem:$v'),
    ];
    return parts.join('|');
  }
}
