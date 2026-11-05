import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:scamlens/core/config/url_config.dart';

abstract class UrlService {
  String normalizeUrl(String rawUrl);
  Future<String> unshortenUrl(String url);
  bool isShortenedUrl(String url);
  String extractRootDomain(String url);
}

class UrlServiceImpl implements UrlService {
  final http.Client _client;

  UrlServiceImpl({http.Client? client}) : _client = client ?? http.Client();

  @override
  bool isShortenedUrl(String url) {
    try {
      final uri = Uri.parse(normalizeUrl(url));
      final host = uri.host.toLowerCase();
      return UrlConfig.knownShorteners.any((shortener) =>
          host == shortener || host.endsWith('.$shortener'));
    } catch (_) {
      return false;
    }
  }

  @override
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
        ..removeWhere((key, _) =>
            UrlConfig.trackingParameters.contains(key.toLowerCase()));

      final normalizedUri = Uri(
        scheme: uri.scheme.toLowerCase(),
        userInfo: uri.userInfo,
        host: uri.host.toLowerCase(),
        port: (uri.port == 80 && uri.scheme == 'http') ||
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

  @override
  Future<String> unshortenUrl(String url) async {
    String currentUrl = normalizeUrl(url);
    int redirects = 0;

    while (redirects < UrlConfig.maxRedirects) {
      final uri = Uri.tryParse(currentUrl);
      if (uri == null || !uri.hasScheme) break;

      try {
        final request = http.Request('HEAD', uri)..followRedirects = false;

        final streamedResponse = await _client
            .send(request)
            .timeout(UrlConfig.requestTimeout);

        final statusCode = streamedResponse.statusCode;
        final location = streamedResponse.headers['location'];

        if ((statusCode == 301 ||
                statusCode == 302 ||
                statusCode == 303 ||
                statusCode == 307 ||
                statusCode == 308) &&
            location != null &&
            location.isNotEmpty) {
          final nextUri = uri.resolve(location);
          currentUrl = nextUri.toString();
          redirects++;
        } else {
          break;
        }
      } catch (_) {
        break;
      }
    }

    return normalizeUrl(currentUrl);
  }

  @override
  String extractRootDomain(String url) {
    try {
      final uri = Uri.parse(normalizeUrl(url));
      final host = uri.host.toLowerCase();
      final parts = host.split('.');
      if (parts.length >= 2) {
        return '${parts[parts.length - 2]}.${parts.last}';
      }
      return host;
    } catch (_) {
      return '';
    }
  }
}
