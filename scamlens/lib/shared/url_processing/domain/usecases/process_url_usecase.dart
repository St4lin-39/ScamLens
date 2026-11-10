import '../entities/url_processing_result.dart';
import '../services/url_expander.dart';
import '../services/url_normalizer.dart';

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
            raw.toLowerCase().startsWith('www.'));

    String normalizedUrl = raw;
    bool wasShortened = false;
    if (isUrl) {
      try {
        final initialNormalized = normalizer.normalizeUrl(raw);
        wasShortened = normalizer.isShortenedUrl(initialNormalized);
        if (wasShortened) {
          normalizedUrl = await _expand(initialNormalized).timeout(
            const Duration(seconds: 3),
            onTimeout: () => initialNormalized,
          );
        } else {
          normalizedUrl = initialNormalized;
        }
      } catch (_) {
        normalizedUrl = raw;
      }
    }

    return UrlProcessingResult(
      contentRaw: raw,
      normalizedUrl: normalizedUrl,
      isUrl: isUrl,
      wasShortened: wasShortened,
    );
  }

  Future<String> _expand(String url) async {
    // Preserve the initial and final normalization of the legacy service.
    final expanded = await expander.expandUrl(normalizer.normalizeUrl(url));
    return normalizer.normalizeUrl(expanded);
  }
}
