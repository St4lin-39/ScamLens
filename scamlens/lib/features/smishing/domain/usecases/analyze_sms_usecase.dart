import '../../../../shared/url_processing/domain/entities/url_processing_result.dart';
import '../../../../shared/url_processing/domain/usecases/process_url_usecase.dart';
import '../entities/sms_analysis_result.dart';
import '../services/sms_url_extractor.dart';

class AnalyzeSmsUseCase {
  final SmsUrlExtractor extractor;
  final ProcessUrlUseCase processUrlUseCase;

  AnalyzeSmsUseCase({required this.extractor, required this.processUrlUseCase});

  Future<SmsAnalysisResult> call(String text) async {
    if (text.trim().isEmpty) {
      throw ArgumentError.value(text, 'text', 'SMS must not be empty');
    }

    final processed = <String, UrlProcessingResult>{};
    final results = <UrlProcessingResult>[];
    for (final url in extractor.extract(text)) {
      var result = processed[url];
      if (result == null) {
        try {
          result = await processUrlUseCase(url);
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
    }
    return SmsAnalysisResult(originalText: text, urls: results);
  }
}
