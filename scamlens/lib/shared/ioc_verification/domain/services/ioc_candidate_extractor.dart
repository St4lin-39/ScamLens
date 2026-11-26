import 'package:scamlens/core/config/url_config.dart';
import 'package:scamlens/shared/brand_impersonation/domain/services/registrable_domain_extractor.dart';
import 'package:scamlens/shared/url_processing/domain/services/web_url_recognizer.dart';

import '../entities/ioc_check_result.dart';

/// Canonicalizes and decomposes URLs into URL, DOMAIN, and IP IOC candidates.
class IocCandidateExtractor {
  static const Set<String> _sharedHostingDomains = {
    'github.io',
    'gitlab.io',
    'pages.dev',
    'vercel.app',
    'netlify.app',
    'web.app',
    'firebaseapp.com',
    'appspot.com',
    'sites.google.com',
    'drive.google.com',
    'docs.google.com',
    'forms.gle',
    'blogspot.com',
    'wordpress.com',
    'tinyurl.com',
  };

  static final RegExp _ipv4Pattern = RegExp(r'^\d{1,3}(\.\d{1,3}){3}$');
  static final RegExp _multiSlash = RegExp(r'/+');

  final RegistrableDomainExtractor domainExtractor;

  IocCandidateExtractor({RegistrableDomainExtractor? domainExtractor})
    : domainExtractor = domainExtractor ?? RegistrableDomainExtractor();

  IocCandidateSet extract({
    required String normalizedUrl,
    String? verifiedDestination,
    Iterable<String> protectedDomains = const [],
  }) {
    final urls = <String>{};
    final domains = <String>{};
    final ips = <String>{};
    final remoteLookupUrls = <String>{};

    final excludedDomains = <String>{
      ...UrlConfig.knownShorteners.map((d) => d.toLowerCase()),
      ..._sharedHostingDomains,
      ...protectedDomains.map((d) => d.trim().toLowerCase()),
    };

    void processSingleUrl(String rawCandidate) {
      final trimmed = rawCandidate.trim();
      if (trimmed.isEmpty) return;

      final withScheme = WebUrlRecognizer.hasHttpScheme(trimmed)
          ? trimmed
          : 'https://$trimmed';

      final uri = Uri.tryParse(withScheme);
      if (uri == null || uri.host.isEmpty) return;

      final scheme = uri.scheme.toLowerCase();
      if (scheme != 'http' && scheme != 'https') return;

      final host = uri.host.toLowerCase();
      final isIpv6 = host.contains(':');
      final isIpv4 = !isIpv6 && _ipv4Pattern.hasMatch(host);

      if (!isIpv6 && !isIpv4 && !WebUrlRecognizer.isWebUrl(withScheme)) {
        return;
      }

      if (isIpv4 || isIpv6) {
        ips.add(host);
      } else {
        _collectDomainLadder(host, excludedDomains, domains);
      }

      final cleanPort =
          uri.hasPort &&
              !((scheme == 'http' && uri.port == 80) ||
                  (scheme == 'https' && uri.port == 443))
          ? uri.port
          : null;

      final hostAuthority = isIpv6 ? '[$host]' : host;
      final portSuffix = cleanPort != null ? ':$cleanPort' : '';
      final authority = '$hostAuthority$portSuffix';

      final rawPath = uri.path.isEmpty
          ? '/'
          : uri.path.replaceAll(_multiSlash, '/');
      final trimmedPath = rawPath.length > 1 && rawPath.endsWith('/')
          ? rawPath.substring(0, rawPath.length - 1)
          : rawPath;

      final filteredQuery = _cleanQueryParameters(uri);
      final querySuffix = filteredQuery.isEmpty ? '' : '?$filteredQuery';

      // Canonical URL for remote threat intelligence lookup
      final remoteUrl = '$scheme://$authority$rawPath$querySuffix';
      remoteLookupUrls.add(remoteUrl);

      // Local URL IOC candidates (handling trailing slash, victim tokens, and scheme variants)
      final canonicalWithQuery = '$scheme://$authority$trimmedPath$querySuffix';
      urls.add(canonicalWithQuery);

      if (trimmedPath == '/') {
        urls.add('$scheme://$authority/');
        urls.add('$scheme://$authority');
      } else {
        urls.add('$scheme://$authority$trimmedPath');
        urls.add('$scheme://$authority$trimmedPath/');

        // Cross-scheme match on specific non-root paths (catches http <-> https evasion)
        final altScheme = scheme == 'https' ? 'http' : 'https';
        if (cleanPort == null) {
          urls.add('$altScheme://$hostAuthority$trimmedPath$querySuffix');
          urls.add('$altScheme://$hostAuthority$trimmedPath');
        }
      }
    }

    processSingleUrl(normalizedUrl);
    if (verifiedDestination != null && verifiedDestination.trim().isNotEmpty) {
      processSingleUrl(verifiedDestination);
    }

    return IocCandidateSet(
      urls: urls,
      domains: domains,
      ips: ips,
      remoteLookupUrls: remoteLookupUrls,
    );
  }

  void _collectDomainLadder(
    String fullHost,
    Set<String> excludedDomains,
    Set<String> target,
  ) {
    final extracted = domainExtractor.extract(fullHost);
    if (extracted == null) return;

    if (excludedDomains.contains(extracted.rootDomain) ||
        excludedDomains.contains(fullHost)) {
      return;
    }

    final hostLabels = fullHost.split('.');
    final rootLabelCount = extracted.rootDomain.split('.').length;

    for (var i = 0; i <= hostLabels.length - rootLabelCount; i++) {
      final candidate = hostLabels.sublist(i).join('.');
      if (candidate == 'www.${extracted.rootDomain}') continue;
      if (!excludedDomains.contains(candidate)) {
        target.add(candidate);
      }
    }
  }

  String _cleanQueryParameters(Uri uri) {
    if (!uri.hasQuery || uri.queryParametersAll.isEmpty) return '';
    final kept = <String>[];
    uri.queryParametersAll.forEach((key, values) {
      if (UrlConfig.trackingParameters.contains(key.toLowerCase())) return;
      for (final val in values) {
        kept.add(
          val.isEmpty
              ? Uri.encodeQueryComponent(key)
              : '${Uri.encodeQueryComponent(key)}=${Uri.encodeQueryComponent(val)}',
        );
      }
    });
    return kept.join('&');
  }
}
