import '../../../../shared/url_processing/domain/entities/url_processing_result.dart';
import '../../../../shared/url_risk/domain/entities/risk_evaluation_result.dart';

/// Preserves the message and one processing result per URL occurrence.
class SmsAnalysisResult {
  final String originalText;
  final List<UrlProcessingResult> urls;

  /// One immutable evaluation per occurrence, at the same index as [urls].
  late final List<RiskEvaluationResult> riskEvaluations;

  SmsAnalysisResult({
    required this.originalText,
    required Iterable<UrlProcessingResult> urls,
    Iterable<RiskEvaluationResult>? riskEvaluations,
  }) : urls = List.unmodifiable(urls) {
    final risks =
        riskEvaluations?.toList() ??
        this.urls
            .map((url) => RiskEvaluationResult.notEvaluated(url.contentRaw))
            .toList();
    if (risks.length != this.urls.length) {
      throw ArgumentError('Each URL occurrence requires one risk evaluation.');
    }
    this.riskEvaluations = List.unmodifiable(risks);
  }
}
