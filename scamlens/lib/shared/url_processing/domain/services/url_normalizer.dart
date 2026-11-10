import 'package:scamlens/core/config/url_config.dart';

class UrlNormalizer {
  bool isShortenedUrl(String url) {
    try {
      final uri = Uri.parse(normalizeUrl(url));
      final host = uri.host.toLowerCase();
      return UrlConfig.knownShorteners.any(
        (shortener) => host == shortener || host.endsWith('.$shortener'),
      );
    } catch (_) {
      return false;
    }
  }

  String normalizeUrl(String rawUrl) {
    String cleaned = rawUrl.trim();
    if (cleaned.isEmpty) return '';

    // Si no tiene esquema, asumimos https://
    if (!cleaned.startsWith('http://') && !cleaned.startsWith('https://')) {
      cleaned = 'https://$cleaned';
    }

    try {
      final uri = Uri.parse(cleaned);

      // Limpiar query parameters de tracking
      final cleanedQueryParams = Map<String, String>.from(uri.queryParameters)
        ..removeWhere(
          (key, _) => UrlConfig.trackingParameters.contains(key.toLowerCase()),
        );

      final normalizedUri = Uri(
        scheme: uri.scheme.toLowerCase(),
        userInfo: uri.userInfo,
        host: uri.host.toLowerCase(),
        port:
            (uri.port == 80 && uri.scheme == 'http') ||
                (uri.port == 443 && uri.scheme == 'https')
            ? null
            : uri.port,
        path: uri.path.isEmpty ? '/' : uri.path,
        queryParameters: cleanedQueryParams.isEmpty ? null : cleanedQueryParams,
        fragment: uri.fragment.isEmpty ? null : uri.fragment,
      );

      return normalizedUri.toString();
    } catch (_) {
      return cleaned;
    }
  }
}
