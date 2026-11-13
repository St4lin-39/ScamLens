import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:scamlens/shared/brand_impersonation/data/datasources/supabase_official_brand_datasource.dart';
import 'package:scamlens/shared/brand_impersonation/data/models/official_brand_model.dart';
import 'package:scamlens/shared/brand_impersonation/data/repositories/official_brand_repository_impl.dart';

class _FakeDatasource implements SupabaseOfficialBrandDatasource {
  int fetchCalls = 0;
  Future<List<OfficialBrandModel>> Function() onFetch = () async => const [];

  @override
  Never get client => throw UnimplementedError();

  @override
  Future<List<OfficialBrandModel>> fetchActiveBrands() {
    fetchCalls++;
    return onFetch();
  }
}

void main() {
  group('OfficialBrandModel & OfficialBrandRepositoryImpl', () {
    test('parses Supabase snake_case JSON and normalizes official_domain', () {
      final model = OfficialBrandModel.fromJson({
        'id': 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
        'entity_name': 'Bancolombia',
        'official_domain': '  BANCOLOMBIA.COM ',
        'category': 'Banca',
        'active': true,
        'created_in': '2026-11-12T00:00:00Z',
      });

      expect(model.id, 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11');
      expect(model.entityName, 'Bancolombia');
      expect(model.officialDomain, 'bancolombia.com');
      expect(model.category, 'Banca');
      expect(model.active, isTrue);
    });

    test('caches remote brands within TTL, coalesces concurrent calls and falls back to last cache offline', () async {
      var now = DateTime.utc(2026, 11, 12, 12, 0, 0);
      final datasource = _FakeDatasource();
      final completer = Completer<List<OfficialBrandModel>>();
      datasource.onFetch = () => completer.future;

      final repo = OfficialBrandRepositoryImpl(
        datasource: datasource,
        cacheTtl: const Duration(minutes: 5),
        clock: () => now,
      );

      // Dos llamadas concurrentes comparten la misma consulta en vuelo
      final f1 = repo.getActiveBrands();
      final f2 = repo.getActiveBrands();
      expect(datasource.fetchCalls, 1);

      completer.complete([
        OfficialBrandModel.fromJson({
          'id': 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
          'entity_name': 'Bancolombia',
          'official_domain': 'bancolombia.com',
          'category': 'Banca',
          'active': true,
          'created_in': '2026-11-12T00:00:00Z',
        }),
      ]);

      final r1 = await f1;
      final r2 = await f2;
      expect(r1.single.officialDomain, 'bancolombia.com');
      expect(r2.single.officialDomain, 'bancolombia.com');

      // Dentro del TTL no vuelve a golpear Supabase
      now = now.add(const Duration(minutes: 3));
      final cached = await repo.getActiveBrands();
      expect(cached, hasLength(1));
      expect(datasource.fetchCalls, 1);

      // Tras expirar el TTL, si falla la red reutiliza la ultima copia real
      now = now.add(const Duration(minutes: 4));
      datasource.onFetch = () async => throw Exception('Offline');
      final stale = await repo.getActiveBrands();
      expect(datasource.fetchCalls, 2);
      expect(stale.single.officialDomain, 'bancolombia.com');

      // Si se invalida la cache manualmente y no hay red, retorna vacio
      repo.invalidateCache();
      final emptyOffline = await repo.getActiveBrands();
      expect(emptyOffline, isEmpty);
    });
  });
}
