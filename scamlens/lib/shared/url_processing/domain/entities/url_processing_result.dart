class UrlProcessingResult {
  final String contentRaw;
  final String normalizedUrl;
  final bool isUrl;
  final bool wasShortened;

  const UrlProcessingResult({
    required this.contentRaw,
    required this.normalizedUrl,
    required this.isUrl,
    required this.wasShortened,
  });
}
