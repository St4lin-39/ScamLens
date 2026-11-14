import 'dart:math' as math;

import '../entities/brand_impersonation_result.dart';
import '../entities/official_brand.dart';
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

    final brands = await repository.getActiveBrands();
    final activeBrands = brands.where((b) => b.active).toList(growable: false);

    // 1. Verificar primero si pertenece legitimamente a una marca oficial
    for (final brand in activeBrands) {
      final official = domainExtractor.extract(brand.officialDomain);
      if (official != null && evaluated.rootDomain == official.rootDomain) {
        return BrandImpersonationResult(
          status: BrandMatchStatus.officialVerified,
          evaluatedRootDomain: evaluated.rootDomain,
          matchedBrand: brand,
          editDistance: 0,
          heuristicDetail: BrandHeuristicDetail(
            ruleName: ruleName,
            impersonatedBrandId: brand.id,
            result: 'VERIFIED_OFFICIAL',
            assignedRiskWeight: 0,
            technicalEvidence:
                'El dominio raiz ${evaluated.rootDomain} coincide con el '
                'dominio oficial verificado de ${brand.entityName}.',
          ),
        );
      }
    }

    // 2. Evaluar typosquatting (distancia 1..3) o mismo nombre en TLD no oficial
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
        evaluatedRootDomain: evaluated.rootDomain,
        matchedBrand: closestBrand,
        editDistance: bestDistance,
        heuristicDetail: BrandHeuristicDetail(
          ruleName: ruleName,
          impersonatedBrandId: closestBrand.id,
          result: 'HIGH_SUSPICION',
          assignedRiskWeight: weight,
          technicalEvidence:
              'El dominio raiz "${evaluated.rootDomain}" presenta una '
              'distancia de edicion de $bestDistance frente a la marca '
              'oficial ${closestBrand.entityName} '
              '(${closestBrand.officialDomain}).',
        ),
      );
    }

    return BrandImpersonationResult(
      status: BrandMatchStatus.noMatch,
      evaluatedRootDomain: evaluated.rootDomain,
    );
  }

  int _maxAllowedDistance(int brandLabelLength) {
    if (brandLabelLength <= 4) return 1;
    if (brandLabelLength <= 7) return 2;
    return 3;
  }
}
