import '../../../../shared/url_processing/domain/entities/url_processing_result.dart';
import '../../../../shared/url_processing/domain/usecases/process_url_usecase.dart';
import '../entities/sms_analysis_result.dart';
import '../services/sms_url_extractor.dart';
import '../../../../shared/url_risk/domain/entities/risk_evaluation_result.dart';
import '../../../../shared/url_risk/domain/usecases/evaluate_url_risk_usecase.dart';
import '../../../../shared/analysis_progress/domain/analysis_progress.dart';

class AnalyzeSmsUseCase {
  final SmsUrlExtractor extractor;
  final ProcessUrlUseCase processUrlUseCase;
  final EvaluateUrlRiskUseCase _evaluateUrlRiskUseCase;

  AnalyzeSmsUseCase({
    required this.extractor,
    required this.processUrlUseCase,
    EvaluateUrlRiskUseCase? evaluateUrlRiskUseCase,
  }) : _evaluateUrlRiskUseCase =
           evaluateUrlRiskUseCase ?? EvaluateUrlRiskUseCase();

  Future<SmsAnalysisResult> call(
    String text, {
    AnalysisProgressCallback? onProgress,
  }) async {
    if (text.trim().isEmpty) {
      throw ArgumentError.value(text, 'text', 'SMS must not be empty');
    }

    notifyAnalysisProgress(
      onProgress,
      const AnalysisProgress(
        AnalysisStage.extractLinks,
        AnalysisStageStatus.active,
      ),
    );
    late final List<String> links;
    try {
      links = extractor.extract(text);
    } catch (_) {
      notifyAnalysisProgress(
        onProgress,
        const AnalysisProgress(
          AnalysisStage.extractLinks,
          AnalysisStageStatus.failed,
          reason: AnalysisProgressReason.error,
        ),
      );
      rethrow;
    }
    final total = links.toSet().length;
    notifyAnalysisProgress(
      onProgress,
      AnalysisProgress(
        AnalysisStage.extractLinks,
        AnalysisStageStatus.completed,
        linkTotal: total,
      ),
    );
    final processed = <String, UrlProcessingResult>{};
    final results = <UrlProcessingResult>[];
    final evaluated = <String, RiskEvaluationResult>{};
    final risks = <RiskEvaluationResult>[];
    for (final url in links) {
      final index = processed.containsKey(url) ? null : processed.length + 1;
      void progress(AnalysisProgress event) =>
          notifyAnalysisProgress(onProgress, event.forLink(index!, total));
      var result = processed[url];
      if (result == null) {
        try {
          result = await processUrlUseCase(url, onProgress: progress);
        } catch (_) {
          // No expansion is confirmed: retain the extracted link unchanged.
          result = UrlProcessingResult(
            contentRaw: url,
            normalizedUrl: url,
            isUrl: true,
            wasShortened: false,
          );
        }
        processed[url] = result;
      }
      results.add(result);
      risks.add(
        evaluated.putIfAbsent(
          url,
          () => _evaluateUrlRiskUseCase(result!, onProgress: progress),
        ),
      );
    }
    notifyAnalysisProgress(
      onProgress,
      const AnalysisProgress(
        AnalysisStage.prepareResult,
        AnalysisStageStatus.active,
      ),
    );
    try {
      final result = SmsAnalysisResult(
        originalText: text,
        urls: results,
        riskEvaluations: risks,
      );
      notifyAnalysisProgress(
        onProgress,
        const AnalysisProgress(
          AnalysisStage.prepareResult,
          AnalysisStageStatus.completed,
        ),
      );
      return result;
    } catch (_) {
      notifyAnalysisProgress(
        onProgress,
        const AnalysisProgress(
          AnalysisStage.prepareResult,
          AnalysisStageStatus.failed,
          reason: AnalysisProgressReason.error,
        ),
      );
      rethrow;
    }
  }
}
