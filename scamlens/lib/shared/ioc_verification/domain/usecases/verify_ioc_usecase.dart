import '../entities/ioc_check_result.dart';
import '../repositories/ioc_repository.dart';
import '../services/ioc_candidate_extractor.dart';

class VerifyIocUseCase {
  static const String ruleName = 'CONFIRMED_IOC_MATCH';

  final IocRepository repository;
  final IocCandidateExtractor candidateExtractor;

  VerifyIocUseCase({
    required this.repository,
    IocCandidateExtractor? candidateExtractor,
  }) : candidateExtractor = candidateExtractor ?? IocCandidateExtractor();

  Future<IocCheckResult> call({
    required String normalizedUrl,
    String? verifiedDestination,
    Iterable<String> protectedDomains = const [],
  }) async {
    final candidates = candidateExtractor.extract(
      normalizedUrl: normalizedUrl,
      verifiedDestination: verifiedDestination,
      protectedDomains: protectedDomains,
    );

    if (candidates.isEmpty) {
      return const IocCheckResult(
        status: IocCheckStatus.notApplicable,
        sourceAvailability: IocSourceAvailability.available,
      );
    }

    final outcome = await repository.checkCandidates(candidates);
    if (!outcome.isConfirmedThreat || outcome.matchedIoc == null) {
      return outcome;
    }

    final ioc = outcome.matchedIoc!;
    return IocCheckResult(
      status: IocCheckStatus.matched,
      sourceAvailability: outcome.sourceAvailability,
      matchedIoc: ioc,
      matchedCandidate: outcome.matchedCandidate ?? ioc.value,
      heuristicDetail:
          outcome.heuristicDetail ??
          IocHeuristicDetail(
            ruleName: ruleName,
            result: 'CONFIRMED_THREAT',
            assignedRiskWeight: 100,
            technicalEvidence:
                'Matched confirmed ${ioc.type.dbCode} indicator "${ioc.value}" '
                'classified as ${ioc.attackType} (source: ${ioc.detectionSource}).',
          ),
    );
  }
}
