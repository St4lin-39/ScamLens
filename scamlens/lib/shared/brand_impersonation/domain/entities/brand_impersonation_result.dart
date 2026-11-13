import 'official_brand.dart';

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
  final BrandMatchStatus status;
  final String? evaluatedRootDomain;
  final OfficialBrand? matchedBrand;
  final int? editDistance;
  final BrandHeuristicDetail? heuristicDetail;

  const BrandImpersonationResult({
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
