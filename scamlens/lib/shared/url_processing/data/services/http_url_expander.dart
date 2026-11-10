import 'package:http/http.dart' as http;
import 'package:scamlens/core/config/url_config.dart';
import 'package:scamlens/shared/url_processing/domain/services/url_expander.dart';

class HttpUrlExpander implements UrlExpander {
  final http.Client _client;

  HttpUrlExpander(this._client);

  @override
  Future<String> expandUrl(String url) async {
    String currentUrl = url;
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

    return currentUrl;
  }
}
