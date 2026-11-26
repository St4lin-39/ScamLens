import 'package:flutter/material.dart';

import '../shared/url_risk/domain/entities/risk_evaluation_result.dart';
import '../theme/app_theme.dart';

/// Shared QR/SMS presentation. No URL launch implementation or network access.
class RiskTrafficLight extends StatelessWidget {
  final RiskEvaluationResult evaluation;

  /// Optional host-provided navigation. Red results can never invoke it.
  /// Existing QR/SMS screens offer no navigation callback.
  final ValueChanged<String>? onOpenUrl;

  const RiskTrafficLight({super.key, required this.evaluation, this.onOpenUrl});

  @override
  Widget build(BuildContext context) {
    final (color, icon, title) = switch (evaluation.level) {
      RiskLevel.green => (
        AppColors.safeGreen,
        Icons.verified_user_outlined,
        'Green · Recognized official domain',
      ),
      RiskLevel.yellow => (
        AppColors.warningYellow,
        Icons.warning_amber_rounded,
        'Yellow · Caution',
      ),
      RiskLevel.red => (
        AppColors.error,
        Icons.gpp_bad_outlined,
        evaluation.hasConfirmedIoc
            ? 'Red · Confirmed malicious threat'
            : 'Red · Possible impersonation',
      ),
    };
    final coverage = switch (evaluation.completeness) {
      RiskAnalysisCompleteness.complete => 'Complete local checks',
      RiskAnalysisCompleteness.partial =>
        'Partial evaluation: insufficient information',
      RiskAnalysisCompleteness.notApplicable => 'Evaluation not applicable',
    };
    final canOpen =
        evaluation.level != RiskLevel.red &&
        evaluation.evaluatedUrl != null &&
        evaluation.completeness != RiskAnalysisCompleteness.notApplicable;
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(color: color, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(evaluation.summary),
            if (evaluation.hasUncertainty) ...[
              const SizedBox(height: 6),
              Text(coverage),
            ],
            if (evaluation.level == RiskLevel.red) ...[
              const SizedBox(height: 6),
              Text(
                evaluation.hasConfirmedIoc
                    ? 'Direct opening blocked: matched a confirmed indicator of compromise (IOC).'
                    : 'Direct opening blocked due to possible impersonation.',
              ),
            ],
            if (onOpenUrl != null)
              OutlinedButton.icon(
                onPressed: canOpen
                    ? () => onOpenUrl!(evaluation.evaluatedUrl!)
                    : null,
                icon: const Icon(Icons.open_in_new),
                label: const Text('Open link'),
              ),
            ExpansionTile(
              key: ObjectKey(evaluation),
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
              title: const Text('Evaluation details'),
              children: [
                Text(coverage),
                if (evaluation.evaluatedUrl case final url?) ...[
                  const SizedBox(height: 8),
                  Text('Evaluated URL: $url'),
                ],
                for (final evidence in evaluation.evidences)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '${evidence.justification}\nObserved link: ${evidence.subject}',
                    ),
                  ),
                const SizedBox(height: 12),
                const Text(
                  'Scope: local heuristics and brand catalog. '
                  'No reputation services or site content inspection. '
                  'An official domain may also be compromised.',
                ),
                const SizedBox(height: 8),
                const Text(
                  'HTTPS and an HTTP-confirmed destination do not guarantee safety. '
                  'An unknown domain does not imply maliciousness either.',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
