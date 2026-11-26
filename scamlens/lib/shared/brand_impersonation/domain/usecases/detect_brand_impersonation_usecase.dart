import 'dart:math' as math;

import '../entities/brand_impersonation_result.dart';
import '../entities/official_brand.dart';
import '../entities/official_brand_catalog.dart';
import '../repositories/official_brand_repository.dart';
import '../services/levenshtein_calculator.dart';
import '../services/registrable_domain_extractor.dart';

class DetectBrandImpersonationUseCase {
  static const String ruleName = 'TYPOSQUATTING_LEVENSHTEIN';

  final OfficialBrandRepository repository;
  final RegistrableDomainExtractor domainExtractor;
  final LevenshteinCalculator calculator;

  DetectBrandImpersonationUseCase({
    required this.repository,
    RegistrableDomainExtractor? domainExtractor,
    this.calculator = const LevenshteinCalculator(),
  }) : domainExtractor = domainExtractor ?? RegistrableDomainExtractor();

  Future<BrandImpersonationResult> call(String urlOrDomain) async {
    final evaluated = domainExtractor.extract(urlOrDomain);
    if (evaluated == null) {
      return const BrandImpersonationResult(
        status: BrandMatchStatus.notApplicable,
      );
    }

    final source = repository;
    final catalog = source is OfficialBrandCatalogReader
        ? await (source as OfficialBrandCatalogReader).getCatalogSnapshot()
        : OfficialBrandCatalog(
            brands: await source.getActiveBrands(),
            status: BrandCatalogStatus.unknown,
          );
    final activeBrands = List<OfficialBrand>.unmodifiable(
      catalog.brands.where((b) => b.active),
    );

    // 1. Verificar primero si pertenece legitimamente a una marca oficial
    for (final brand in activeBrands) {
      final official = domainExtractor.extract(brand.officialDomain);
      if (official != null && evaluated.rootDomain == official.rootDomain) {
        return BrandImpersonationResult(
          status: BrandMatchStatus.officialVerified,
          catalogStatus: catalog.status,
          evaluatedBrands: activeBrands,
          evaluatedRootDomain: evaluated.rootDomain,
          matchedBrand: brand,
          editDistance: 0,
          heuristicDetail: BrandHeuristicDetail(
            ruleName: ruleName,
            impersonatedBrandId: brand.id,
            result: 'VERIFIED_OFFICIAL',
            assignedRiskWeight: 0,
            technicalEvidence:
                'The root domain ${evaluated.rootDomain} matches the '
                'verified official domain of ${brand.entityName}.',
          ),
        );
      }
    }

    // 2. Evaluate typosquatting (distance 1..3) or exact brand name on non-official TLD
    OfficialBrand? closestBrand;
    int? bestDistance;

    for (final brand in activeBrands) {
      final official = domainExtractor.extract(brand.officialDomain);
      if (official == null) continue;

      final maxAllowed = _maxAllowedDistance(official.brandLabel.length);
      final labelDistance = calculator.distance(
        evaluated.brandLabel,
        official.brandLabel,
      );
      final rootDistance = calculator.distance(
        evaluated.rootDomain,
        official.rootDomain,
      );

      final isSameBrandWrongTld = labelDistance == 0;
      final isTypoWithinThreshold =
          (labelDistance >= 1 && labelDistance <= maxAllowed) ||
          (rootDistance >= 1 && rootDistance <= maxAllowed);

      if (!isSameBrandWrongTld && !isTypoWithinThreshold) continue;

      final effectiveDistance = isSameBrandWrongTld
          ? math.min(rootDistance, 3)
          : math.min(labelDistance, rootDistance);

      if (bestDistance == null || effectiveDistance < bestDistance) {
        bestDistance = effectiveDistance;
        closestBrand = brand;
      }
    }

    if (closestBrand != null && bestDistance != null) {
      final weight = switch (bestDistance) {
        0 || 1 => 90,
        2 => 80,
        _ => 70,
      };

      return BrandImpersonationResult(
        status: BrandMatchStatus.suspectedImpersonation,
        catalogStatus: catalog.status,
        evaluatedBrands: activeBrands,
        evaluatedRootDomain: evaluated.rootDomain,
        matchedBrand: closestBrand,
        editDistance: bestDistance,
        heuristicDetail: BrandHeuristicDetail(
          ruleName: ruleName,
          impersonatedBrandId: closestBrand.id,
          result: 'HIGH_SUSPICION',
          assignedRiskWeight: weight,
          technicalEvidence:
              'The root domain "${evaluated.rootDomain}" has an edit '
              'distance of $bestDistance compared to the official brand '
              '${closestBrand.entityName} (${closestBrand.officialDomain}).',
        ),
      );
    }

    return BrandImpersonationResult(
      status: BrandMatchStatus.noMatch,
      catalogStatus: catalog.status,
      evaluatedBrands: activeBrands,
      evaluatedRootDomain: evaluated.rootDomain,
    );
  }

  int _maxAllowedDistance(int brandLabelLength) {
    if (brandLabelLength <= 4) return 1;
    if (brandLabelLength <= 7) return 2;
    return 3;
  }
}
