import 'package:flutter/material.dart';

import '../shared/analysis_progress/domain/analysis_progress.dart';
import '../theme/app_theme.dart';

class AnalysisProgressView extends StatelessWidget {
  final AnalysisProgressSnapshot progress;
  final bool running;
  const AnalysisProgressView({
    super.key,
    required this.progress,
    this.running = true,
  });

  static String label(AnalysisStage stage) => switch (stage) {
    AnalysisStage.extractLinks => 'Extracting SMS links',
    AnalysisStage.normalizeUrl => 'Recognizing and normalizing URL',
    AnalysisStage.expandShortener => 'Checking shortener destination',
    AnalysisStage.brandCheck => 'Evaluating possible brand impersonation',
    AnalysisStage.iocCheck => 'Checking confirmed threat indicators (IOCs)',
    AnalysisStage.evaluateRisk =>
      'Applying local heuristics and calculating risk',
    AnalysisStage.prepareResult => 'Preparing result',
  };

  static String reason(AnalysisProgressReason? reason) => switch (reason) {
    AnalysisProgressReason.timeout => 'Timed out',
    AnalysisProgressReason.blocked => 'Blocked by security policy',
    AnalysisProgressReason.cancelled => 'Operation cancelled',
    AnalysisProgressReason.unsupportedPlatform =>
      'Unavailable on this platform',
    AnalysisProgressReason.catalogUnavailable => 'Catalog unavailable',
    AnalysisProgressReason.catalogStale => 'Stale catalog',
    AnalysisProgressReason.catalogUnknown => 'Unknown catalog availability',
    AnalysisProgressReason.notApplicable => 'Not applicable',
    AnalysisProgressReason.notConfigured => 'Check not configured',
    AnalysisProgressReason.error => 'Operation failed',
    null => '',
  };

  Widget _row(AnalysisProgress event, {bool includeLink = false}) {
    final (icon, status) = switch (event.status) {
      AnalysisStageStatus.active => (Icons.hourglass_top, 'In progress'),
      AnalysisStageStatus.completed => (
        Icons.check_circle_outline,
        'Completed',
      ),
      AnalysisStageStatus.skipped => (Icons.skip_next_outlined, 'Skipped'),
      AnalysisStageStatus.failed => (Icons.error_outline, 'Failed'),
      AnalysisStageStatus.unavailable => (Icons.block, 'Unavailable'),
    };
    final prefix = includeLink && event.linkIndex != null
        ? 'Unique link ${event.linkIndex} of ${event.linkTotal}: '
        : '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$prefix${label(event.stage)} · $status'
              '${event.reason == null ? '' : ': ${reason(event.reason)}'}',
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!running && progress.stages.isEmpty) return const SizedBox.shrink();
    final linked = progress.stages.where((e) => e.linkIndex != null);
    final current = linked.isEmpty ? null : linked.last;
    final rows = progress.stages.where(
      (e) => e.linkIndex == null || e.linkIndex == current?.linkIndex,
    );
    final unavailable = progress.stages.any(
      (e) => e.reason == AnalysisProgressReason.unsupportedPlatform,
    );
    return Material(
      type: MaterialType.transparency,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (running) ...[
            Semantics(
              liveRegion: true,
              child: const Text('Analysis in progress'),
            ),
            if (current != null)
              Text('Unique link ${current.linkIndex} of ${current.linkTotal}'),
            if (progress.stages.isEmpty)
              const Text('Waiting for analysis observations...'),
            for (final event in rows) _row(event),
          ] else
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('Analysis stages'),
              children: [
                for (final event in progress.stages)
                  _row(event, includeLink: true),
              ],
            ),
          if (unavailable)
            const Text(
              'Shortener verification is unavailable on this platform.',
            ),
        ],
      ),
    );
  }
}
