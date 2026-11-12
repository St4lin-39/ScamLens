import '../../../../shared/url_processing/domain/entities/url_processing_result.dart';

/// Preserves the message and one processing result per URL occurrence.
class SmsAnalysisResult {
  final String originalText;
  final List<UrlProcessingResult> urls;

  SmsAnalysisResult({
    required this.originalText,
    required Iterable<UrlProcessingResult> urls,
  }) : urls = List.unmodifiable(urls);
}
