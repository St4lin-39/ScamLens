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
        'Verde · Dominio oficial reconocido',
      ),
      RiskLevel.yellow => (
        AppColors.warningYellow,
        Icons.warning_amber_rounded,
        'Amarillo · Precaución',
      ),
      RiskLevel.red => (
        AppColors.error,
        Icons.gpp_bad_outlined,
        'Rojo · Posible suplantación',
      ),
    };
    final coverage = switch (evaluation.completeness) {
      RiskAnalysisCompleteness.complete => 'Comprobaciones locales completas',
      RiskAnalysisCompleteness.partial =>
        'Evaluación parcial: información insuficiente',
      RiskAnalysisCompleteness.notApplicable => 'Evaluación no aplicable',
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
              const Text(
                'Apertura directa bloqueada por posible suplantación.',
              ),
            ],
            if (onOpenUrl != null)
              OutlinedButton.icon(
                onPressed: canOpen
                    ? () => onOpenUrl!(evaluation.evaluatedUrl!)
                    : null,
                icon: const Icon(Icons.open_in_new),
                label: const Text('Abrir enlace'),
              ),
            ExpansionTile(
              key: ObjectKey(evaluation),
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
              title: const Text('Detalles de la evaluación'),
              children: [
                Text(coverage),
                if (evaluation.evaluatedUrl case final url?) ...[
                  const SizedBox(height: 8),
                  Text('URL evaluada: $url'),
                ],
                for (final evidence in evaluation.evidences)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '${evidence.justification}\nEnlace observado: ${evidence.subject}',
                    ),
                  ),
                const SizedBox(height: 12),
                const Text(
                  'Alcance: heurísticas locales y catálogo de marcas. '
                  'Sin servicios de reputación ni inspección del contenido del sitio. '
                  'Un dominio oficial también puede estar comprometido.',
                ),
                const SizedBox(height: 8),
                const Text(
                  'HTTPS y un destino confirmado por HTTP no garantizan seguridad. '
                  'Un dominio desconocido tampoco implica que sea malicioso.',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
