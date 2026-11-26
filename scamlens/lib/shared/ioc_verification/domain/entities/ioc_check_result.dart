import 'indicator_of_compromise.dart';

enum IocCheckStatus { notApplicable, clean, matched }

enum IocSourceAvailability { available, partial, unavailable, notConfigured }

class IocCandidateSet {
  final Set<String> urls;
  final Set<String> domains;
  final Set<String> ips;
  final Set<String> remoteLookupUrls;

  IocCandidateSet({
    Iterable<String> urls = const [],
    Iterable<String> domains = const [],
    Iterable<String> ips = const [],
    Iterable<String> remoteLookupUrls = const [],
  }) : urls = Set.unmodifiable(urls),
       domains = Set.unmodifiable(domains),
       ips = Set.unmodifiable(ips),
       remoteLookupUrls = Set.unmodifiable(remoteLookupUrls);

  bool get isEmpty =>
      urls.isEmpty &&
      domains.isEmpty &&
      ips.isEmpty &&
      remoteLookupUrls.isEmpty;

  List<String> get allLocalValues =>
      <String>{...urls, ...domains, ...ips}.toList(growable: false);
}

class IocHeuristicDetail {
  final String ruleName;
  final String result;
  final int assignedRiskWeight;
  final String technicalEvidence;

  const IocHeuristicDetail({
    required this.ruleName,
    required this.result,
    required this.assignedRiskWeight,
    required this.technicalEvidence,
  });
}

class IocCheckResult {
  final IocCheckStatus status;
  final IocSourceAvailability sourceAvailability;
  final IndicatorOfCompromise? matchedIoc;
  final String? matchedCandidate;
  final IocHeuristicDetail? heuristicDetail;

  const IocCheckResult({
    required this.status,
    required this.sourceAvailability,
    this.matchedIoc,
    this.matchedCandidate,
    this.heuristicDetail,
  });

  bool get isConfirmedThreat =>
      status == IocCheckStatus.matched && matchedIoc != null;
}
