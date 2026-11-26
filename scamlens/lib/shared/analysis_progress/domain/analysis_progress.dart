enum AnalysisStage {
  extractLinks,
  normalizeUrl,
  expandShortener,
  brandCheck,
  iocCheck,
  evaluateRisk,
  prepareResult,
}

enum AnalysisStageStatus { active, completed, skipped, failed, unavailable }

enum AnalysisProgressReason {
  notApplicable,
  notConfigured,
  timeout,
  blocked,
  cancelled,
  catalogStale,
  catalogUnknown,
  catalogUnavailable,
  unsupportedPlatform,
  error,
}

typedef AnalysisProgressCallback = void Function(AnalysisProgress event);

/// Observations of actual work, not a safety verdict or a percentage.
class AnalysisProgress {
  final AnalysisStage stage;
  final AnalysisStageStatus status;
  final AnalysisProgressReason? reason;
  final int? linkIndex;
  final int? linkTotal;

  const AnalysisProgress(
    this.stage,
    this.status, {
    this.reason,
    this.linkIndex,
    this.linkTotal,
  });

  AnalysisProgress forLink(int index, int total) => AnalysisProgress(
    stage,
    status,
    reason: reason,
    linkIndex: index,
    linkTotal: total,
  );
}

/// A detached immutable snapshot, retaining the last observation per stage/link.
class AnalysisProgressSnapshot {
  final List<AnalysisProgress> stages;
  const AnalysisProgressSnapshot.empty() : stages = const [];
  AnalysisProgressSnapshot(Iterable<AnalysisProgress> stages)
    : stages = List.unmodifiable(stages);

  AnalysisProgressSnapshot add(AnalysisProgress event) =>
      AnalysisProgressSnapshot([
        for (final previous in stages)
          if (previous.stage != event.stage ||
              previous.linkIndex != event.linkIndex)
            previous,
        event,
      ]);
}

/// Observers must never change the outcome of the analysis.
void notifyAnalysisProgress(
  AnalysisProgressCallback? observer,
  AnalysisProgress event,
) {
  try {
    observer?.call(event);
  } catch (_) {
    /* Observational only. */
  }
}
