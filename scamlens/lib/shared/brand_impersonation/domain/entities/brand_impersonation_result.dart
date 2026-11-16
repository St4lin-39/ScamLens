import 'official_brand.dart';
import 'official_brand_catalog.dart';

enum BrandMatchStatus {
  notApplicable,
  noMatch,
  officialVerified,
  suspectedImpersonation,
}

class BrandHeuristicDetail {
  final String ruleName;
  final String? impersonatedBrandId;
  final String result;
  final int assignedRiskWeight;
  final String? technicalEvidence;

  const BrandHeuristicDetail({
    required this.ruleName,
    this.impersonatedBrandId,
    required this.result,
    required this.assignedRiskWeight,
    this.technicalEvidence,
  });
}

class BrandImpersonationResult {
  final BrandCatalogStatus catalogStatus;

  /// Immutable snapshot supplied by the detector, reused by local risk checks.
  final List<OfficialBrand> evaluatedBrands;
  final BrandMatchStatus status;
  final String? evaluatedRootDomain;
  final OfficialBrand? matchedBrand;
  final int? editDistance;
  final BrandHeuristicDetail? heuristicDetail;

  const BrandImpersonationResult({
    this.catalogStatus = BrandCatalogStatus.unknown,
    this.evaluatedBrands = const [],
    required this.status,
    this.evaluatedRootDomain,
    this.matchedBrand,
    this.editDistance,
    this.heuristicDetail,
  });

  bool get isSuspectedImpersonation =>
      status == BrandMatchStatus.suspectedImpersonation;

  bool get isOfficialVerified => status == BrandMatchStatus.officialVerified;
}
