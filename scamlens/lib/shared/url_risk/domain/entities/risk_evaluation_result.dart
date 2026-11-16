import 'risk_evidence.dart';

enum RiskLevel { green, yellow, red }

/// Completeness describes only this local profile, not global site safety.
enum RiskAnalysisCompleteness { complete, partial, notApplicable }

class RiskEvaluationResult {
  static const policyVersion = 'local-v1';
  final RiskLevel level;
  final List<RiskEvidence> evidences;
  final RiskAnalysisCompleteness completeness;
  final List<RiskEvidenceId> uncertaintyReasons;

  /// Null for unresolved shorteners and non-URL input.
  final String? evaluatedUrl;

  RiskEvaluationResult({
    required this.level,
    required Iterable<RiskEvidence> evidences,
    required this.completeness,
    required Iterable<RiskEvidenceId> uncertaintyReasons,
    required this.evaluatedUrl,
  }) : evidences = List.unmodifiable(evidences),
       uncertaintyReasons = List.unmodifiable(uncertaintyReasons);

  bool get hasUncertainty => uncertaintyReasons.isNotEmpty;

  /// Conservative compatibility for producers that have not run the evaluator.
  factory RiskEvaluationResult.notEvaluated(String subject) =>
      RiskEvaluationResult(
        level: RiskLevel.yellow,
        evidences: [
          RiskEvidence(
            id: RiskEvidenceId.evaluationUnavailable,
            severity: EvidenceSeverity.caution,
            justification:
                'No se dispone de una evaluación de riesgo para este enlace.',
            subject: subject,
          ),
        ],
        completeness: RiskAnalysisCompleteness.partial,
        uncertaintyReasons: [RiskEvidenceId.evaluationUnavailable],
        evaluatedUrl: null,
      );

  String get summary => switch (level) {
    RiskLevel.green =>
      'Dominio oficial reconocido, sin señales locales detectadas. '
          'No garantiza seguridad absoluta.',
    RiskLevel.yellow =>
      'Precaución: existen señales de riesgo o información insuficiente.',
    RiskLevel.red => 'Posible suplantación: se detectó una señal local fuerte.',
  };
}
