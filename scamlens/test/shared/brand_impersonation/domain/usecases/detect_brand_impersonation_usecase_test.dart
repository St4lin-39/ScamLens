import 'package:flutter_test/flutter_test.dart';
import 'package:scamlens/shared/brand_impersonation/domain/entities/brand_impersonation_result.dart';
import 'package:scamlens/shared/brand_impersonation/domain/entities/official_brand.dart';
import 'package:scamlens/shared/brand_impersonation/domain/repositories/official_brand_repository.dart';
import 'package:scamlens/shared/brand_impersonation/domain/usecases/detect_brand_impersonation_usecase.dart';

class _FakeBrandRepository implements OfficialBrandRepository {
  final List<OfficialBrand> brands;

  _FakeBrandRepository(this.brands);

  @override
  Future<List<OfficialBrand>> getActiveBrands() async => brands;

  @override
  void invalidateCache() {}
}

void main() {
  final epoch = DateTime.utc(2026, 11, 12);

  final catalog = <OfficialBrand>[
    OfficialBrand(
      id: '11111111-1111-4111-8111-111111111111',
      entityName: 'Bancolombia',
      officialDomain: 'bancolombia.com',
      category: 'Banca',
      active: true,
      createdIn: epoch,
    ),
    OfficialBrand(
      id: '22222222-2222-4222-8222-222222222222',
      entityName: 'Banco de Bogota',
      officialDomain: 'bancodebogota.com',
      category: 'Banca',
      active: true,
      createdIn: epoch,
    ),
    OfficialBrand(
      id: '33333333-3333-4333-8333-333333333333',
      entityName: 'Nequi',
      officialDomain: 'nequi.com.co',
      category: 'Billetera Digital',
      active: true,
      createdIn: epoch,
    ),
    OfficialBrand(
      id: '44444444-4444-4444-8444-444444444444',
      entityName: 'DIAN',
      officialDomain: 'dian.gov.co',
      category: 'Gobierno',
      active: true,
      createdIn: epoch,
    ),
    OfficialBrand(
      id: '55555555-5555-4555-8555-555555555555',
      entityName: 'Marca Inactiva',
      officialDomain: 'marcainactiva.com',
      category: 'Otro',
      active: false,
      createdIn: epoch,
    ),
  ];

  late DetectBrandImpersonationUseCase useCase;

  setUp(() {
    useCase = DetectBrandImpersonationUseCase(
      repository: _FakeBrandRepository(catalog),
    );
  });

  group('DetectBrandImpersonationUseCase', () {
    test('verifies exact official domains and legitimate subdomains', () async {
      final root = await useCase('https://bancolombia.com/personas');
      expect(root.status, BrandMatchStatus.officialVerified);
      expect(root.isOfficialVerified, isTrue);
      expect(root.editDistance, 0);
      expect(root.matchedBrand?.id, '11111111-1111-4111-8111-111111111111');
      expect(root.heuristicDetail?.assignedRiskWeight, 0);

      final subdomain = await useCase(
        'https://sucursalpersonas.bancolombia.com/login',
      );
      expect(subdomain.status, BrandMatchStatus.officialVerified);
      expect(subdomain.evaluatedRootDomain, 'bancolombia.com');

      final compound = await useCase('https://muisca.dian.gov.co/Web');
      expect(compound.status, BrandMatchStatus.officialVerified);
      expect(compound.evaluatedRootDomain, 'dian.gov.co');
    });

    test('detects typosquatting with edit distance 1 to 3 and attaches UUID', () async {
      final dist1 = await useCase('https://seguridad.bancol0mbia.com/clave');
      expect(dist1.status, BrandMatchStatus.suspectedImpersonation);
      expect(dist1.isSuspectedImpersonation, isTrue);
      expect(dist1.evaluatedRootDomain, 'bancol0mbia.com');
      expect(dist1.editDistance, 1);
      expect(
        dist1.heuristicDetail?.impersonatedBrandId,
        '11111111-1111-4111-8111-111111111111',
      );
      expect(dist1.heuristicDetail?.assignedRiskWeight, 90);

      final dist2 = await useCase('https://pagos.n3qu1.com.co/recarga');
      expect(dist2.status, BrandMatchStatus.suspectedImpersonation);
      expect(dist2.editDistance, 2);
      expect(
        dist2.heuristicDetail?.impersonatedBrandId,
        '33333333-3333-4333-8333-333333333333',
      );
      expect(dist2.heuristicDetail?.assignedRiskWeight, 80);

      final dist3 = await useCase('https://banc0-bogota.xyz/auth');
      expect(dist3.status, BrandMatchStatus.suspectedImpersonation);
      expect(dist3.editDistance, 3);
      expect(
        dist3.heuristicDetail?.impersonatedBrandId,
        '22222222-2222-4222-8222-222222222222',
      );
      expect(dist3.heuristicDetail?.assignedRiskWeight, 70);
    });

    test('detects exact brand label hosted on unauthorized TLD', () async {
      final wrongTld = await useCase('https://bancolombia.xyz/personas');
      expect(wrongTld.status, BrandMatchStatus.suspectedImpersonation);
      expect(wrongTld.matchedBrand?.entityName, 'Bancolombia');

      final nequiWrongTld = await useCase('https://nequi.xyz/login');
      expect(nequiWrongTld.status, BrandMatchStatus.suspectedImpersonation);
      expect(nequiWrongTld.matchedBrand?.entityName, 'Nequi');
    });

    test('avoids false positives on short brand names while catching close typos', () async {
      // "bing" y "visa" tienen distancia 3 frente a "dian", no deben ser falsos positivos
      final bing = await useCase('https://www.bing.com/search?q=test');
      expect(bing.status, BrandMatchStatus.noMatch);

      final visa = await useCase('https://www.visa.com/');
      expect(visa.status, BrandMatchStatus.noMatch);

      // En cambio "d1an.gov.co" tiene distancia 1 y SI debe detectarse
      final d1an = await useCase('https://d1an.gov.co/impuestos');
      expect(d1an.status, BrandMatchStatus.suspectedImpersonation);
      expect(d1an.matchedBrand?.entityName, 'DIAN');
    });

    test('ignores inactive brands and returns notApplicable for non-domain inputs', () async {
      final inactive = await useCase('https://marcainact1va.com/');
      expect(inactive.status, BrandMatchStatus.noMatch);

      final ip = await useCase('https://192.168.0.1/admin');
      expect(ip.status, BrandMatchStatus.notApplicable);
    });
  });
}
