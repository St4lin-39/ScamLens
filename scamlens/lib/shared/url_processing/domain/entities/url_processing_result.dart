import 'url_expansion_result.dart';

class UrlProcessingResult {
  /// Original content supplied by the caller, independent of normalizedUrl.
  final String contentRaw;

  /// Normalized input for presentation, never an expansion destination.
  final String normalizedUrl;
  final bool isUrl;
  final bool wasShortened;

  /// Null means the legacy producer supplied no typed expansion observations.
  /// It must not be interpreted as notAttempted, failure or success.
  final UrlExpansionResult? expansion;

  const UrlProcessingResult({
    required this.contentRaw,
    required this.normalizedUrl,
    required this.isUrl,
    required this.wasShortened,
    this.expansion,
  });
}
