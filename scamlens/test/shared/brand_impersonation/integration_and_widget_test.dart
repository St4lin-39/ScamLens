import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scamlens/components/brand_impersonation_banner.dart';
import 'package:scamlens/shared/brand_impersonation/domain/entities/brand_impersonation_result.dart';
import 'package:scamlens/shared/brand_impersonation/domain/entities/official_brand.dart';
import 'package:scamlens/shared/brand_impersonation/domain/repositories/official_brand_repository.dart';
import 'package:scamlens/shared/brand_impersonation/domain/usecases/detect_brand_impersonation_usecase.dart';
import 'package:scamlens/shared/url_processing/domain/entities/url_expansion_result.dart';
import 'package:scamlens/shared/url_processing/domain/services/url_expander.dart';
import 'package:scamlens/shared/url_processing/domain/services/url_normalizer.dart';
import 'package:scamlens/shared/url_processing/domain/usecases/process_url_usecase.dart';

class _StubExpander implements UrlExpander {
  final String destination;
  _StubExpander(this.destination);

  @override
  Future<UrlExpansionResult> expandUrl(String url) async {
    return UrlExpansionResult(
      status: UrlExpansionStatus.resolved,
      redirectCount: 1,
      announcedDestination: destination,
      verifiedDestination: destination,
      lastHttpStatus: 200,
    );
  }
}

class _StubBrandRepo implements OfficialBrandRepository {
  final List<OfficialBrand> brands;
  _StubBrandRepo(this.brands);

  @override
  Future<List<OfficialBrand>> getActiveBrands() async => brands;

  @override
  void invalidateCache() {}
}

void main() {
  final brand = OfficialBrand(
    id: '22222222-2222-4222-8222-222222222222',
    entityName: 'Banco de Bogota',
    officialDomain: 'bancodebogota.com',
    category: 'Banca',
    active: true,
    createdIn: DateTime.utc(2026, 11, 12),
  );

  test('ProcessUrlUseCase evaluates expanded destination behind a shortener', () async {
    final processUrl = ProcessUrlUseCase(
      normalizer: UrlNormalizer(),
      expander: _StubExpander('https://banc0-bogota.xyz/login'),
      detectBrandImpersonationUseCase: DetectBrandImpersonationUseCase(
        repository: _StubBrandRepo([brand]),
      ),
    );

    final result = await processUrl('https://bit.ly/oferta-urgente');

    expect(result.wasShortened, isTrue);
    expect(result.expansion?.verifiedDestination, 'https://banc0-bogota.xyz/login');
    expect(result.brandImpersonation?.isSuspectedImpersonation, isTrue);
    expect(result.brandImpersonation?.matchedBrand?.entityName, 'Banco de Bogota');
    expect(result.brandImpersonation?.editDistance, 3);
  });

  testWidgets('BrandImpersonationBanner renders alert for impersonation and badge for verified official', (tester) async {
    final impersonation = BrandImpersonationResult(
      status: BrandMatchStatus.suspectedImpersonation,
      evaluatedRootDomain: 'banc0-bogota.xyz',
      matchedBrand: brand,
      editDistance: 3,
      heuristicDetail: const BrandHeuristicDetail(
        ruleName: 'TYPOSQUATTING_LEVENSHTEIN',
        impersonatedBrandId: '22222222-2222-4222-8222-222222222222',
        result: 'HIGH_SUSPICION',
        assignedRiskWeight: 70,
        technicalEvidence: 'Distancia de edicion 3 frente a bancodebogota.com.',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BrandImpersonationBanner(impersonation: impersonation),
        ),
      ),
    );

    expect(find.text('POSIBLE SUPLANTACION DE MARCA'), findsOneWidget);
    expect(
      find.textContaining('Banco de Bogota (bancodebogota.com)'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Distancia de edicion 3'),
      findsOneWidget,
    );

    final verified = BrandImpersonationResult(
      status: BrandMatchStatus.officialVerified,
      evaluatedRootDomain: 'bancodebogota.com',
      matchedBrand: brand,
      editDistance: 0,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BrandImpersonationBanner(impersonation: verified),
        ),
      ),
    );

    expect(
      find.text('Dominio oficial verificado: Banco de Bogota (bancodebogota.com)'),
      findsOneWidget,
    );
  });
}
