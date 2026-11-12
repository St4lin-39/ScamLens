import '../entities/url_processing_result.dart';
import '../entities/url_expansion_result.dart';
import '../services/url_expander.dart';
import '../services/url_normalizer.dart';
import '../services/web_url_recognizer.dart';

class ProcessUrlUseCase {
  final UrlNormalizer normalizer;
  final UrlExpander expander;

  ProcessUrlUseCase({required this.normalizer, required this.expander});

  /// Rejects empty content; the caller supplies any presentation-specific message.
  Future<UrlProcessingResult> call(String content) async {
    final raw = content.trim();
    if (raw.isEmpty) {
      throw ArgumentError.value(
        content,
        'content',
        'Content must not be empty',
      );
    }

    final uri = Uri.tryParse(raw);
    final isUrl =
        uri != null &&
        ((uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https')) ||
            raw.toLowerCase().startsWith('www.') ||
            WebUrlRecognizer.isWebUrl(raw));

    String normalizedUrl = raw;
    bool wasShortened = false;
    var expansion = UrlExpansionResult(status: UrlExpansionStatus.notAttempted);
    if (isUrl) {
      try {
        final initialNormalized = normalizer.normalizeUrl(raw);
        wasShortened = normalizer.isShortenedUrl(initialNormalized);
        normalizedUrl = initialNormalized;
      } catch (_) {
        normalizedUrl = raw;
        expansion = UrlExpansionResult(
          status: UrlExpansionStatus.failed,
          failureReason: UrlExpansionFailureReason.unknown,
        );
      }
      if (wasShortened) {
        // Display normalization must not change the URI sent to the server.
        final requestUrl = WebUrlRecognizer.hasHttpScheme(raw)
            ? raw
            : 'https://$raw';
        try {
          expansion = await expander.expandUrl(requestUrl);
        } catch (_) {
          expansion = UrlExpansionResult(
            status: UrlExpansionStatus.failed,
            failureReason: UrlExpansionFailureReason.unknown,
          );
        }
      }
    }

    return UrlProcessingResult(
      contentRaw: content,
      normalizedUrl: normalizedUrl,
      isUrl: isUrl,
      wasShortened: wasShortened,
      expansion: expansion,
    );
  }
}
