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
    AnalysisStage.extractLinks => 'Extrayendo enlaces del SMS',
    AnalysisStage.normalizeUrl => 'Reconociendo y normalizando URL',
    AnalysisStage.expandShortener => 'Comprobando destino del acortador',
    AnalysisStage.brandCheck => 'Evaluando posible suplantación de marca',
    AnalysisStage.evaluateRisk =>
      'Aplicando heurísticas locales y calculando riesgo',
    AnalysisStage.prepareResult => 'Preparando resultado',
  };

  static String reason(AnalysisProgressReason? reason) => switch (reason) {
    AnalysisProgressReason.timeout => 'Tiempo agotado',
    AnalysisProgressReason.blocked => 'Bloqueada por política de seguridad',
    AnalysisProgressReason.cancelled => 'Operación cancelada',
    AnalysisProgressReason.unsupportedPlatform =>
      'No disponible en esta plataforma',
    AnalysisProgressReason.catalogUnavailable => 'Catálogo no disponible',
    AnalysisProgressReason.catalogStale => 'Catálogo vencido',
    AnalysisProgressReason.catalogUnknown =>
      'Disponibilidad del catálogo desconocida',
    AnalysisProgressReason.notApplicable => 'No aplica',
    AnalysisProgressReason.notConfigured => 'Comprobación no configurada',
    AnalysisProgressReason.error => 'La operación falló',
    null => '',
  };

  Widget _row(AnalysisProgress event, {bool includeLink = false}) {
    final (icon, status) = switch (event.status) {
      AnalysisStageStatus.active => (Icons.hourglass_top, 'En curso'),
      AnalysisStageStatus.completed => (
        Icons.check_circle_outline,
        'Completada',
      ),
      AnalysisStageStatus.skipped => (Icons.skip_next_outlined, 'Omitida'),
      AnalysisStageStatus.failed => (Icons.error_outline, 'Fallida'),
      AnalysisStageStatus.unavailable => (Icons.block, 'No disponible'),
    };
    final prefix = includeLink && event.linkIndex != null
        ? 'Enlace único ${event.linkIndex} de ${event.linkTotal}: '
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
            Semantics(liveRegion: true, child: const Text('Análisis en curso')),
            if (current != null)
              Text('Enlace único ${current.linkIndex} de ${current.linkTotal}'),
            if (progress.stages.isEmpty)
              const Text('Esperando observaciones del análisis...'),
            for (final event in rows) _row(event),
          ] else
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('Etapas del análisis'),
              children: [
                for (final event in progress.stages)
                  _row(event, includeLink: true),
              ],
            ),
          if (unavailable)
            const Text(
              'La comprobación del acortador no está disponible en esta plataforma.',
            ),
        ],
      ),
    );
  }
}
