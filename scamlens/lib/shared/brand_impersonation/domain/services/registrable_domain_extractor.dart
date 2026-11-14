import 'package:scamlens/shared/url_processing/domain/services/web_url_recognizer.dart';

class ExtractedDomain {
  final String fullHost;
  final String rootDomain;
  final String brandLabel;
  final String publicSuffix;

  const ExtractedDomain({
    required this.fullHost,
    required this.rootDomain,
    required this.brandLabel,
    required this.publicSuffix,
  });
}

class RegistrableDomainExtractor {
  static const Set<String> _compoundSuffixes = {
    'com.co',
    'edu.co',
    'gov.co',
    'org.co',
    'net.co',
    'mil.co',
    'com.mx',
    'gob.mx',
    'com.ar',
    'com.br',
    'com.pe',
    'com.ec',
    'co.uk',
    'org.uk',
    'com.es',
  };

  static final RegExp _numericHost = RegExp(r'^[0-9.]+$');

  ExtractedDomain? extract(String urlOrDomain) {
    final trimmed = urlOrDomain.trim();
    if (trimmed.isEmpty) return null;

    final candidate = WebUrlRecognizer.hasHttpScheme(trimmed)
        ? trimmed
        : 'https://$trimmed';

    final uri = Uri.tryParse(candidate);
    if (uri == null || uri.host.isEmpty) return null;

    final host = uri.host.toLowerCase();
    // Descartar literales IPv6 o IPv4 (no son nombres de marca)
    if (host.contains(':') || _numericHost.hasMatch(host)) return null;

    final labels = host.split('.');
    if (labels.length < 2 || labels.any((part) => part.isEmpty)) {
      return null;
    }

    final lastTwo = '${labels[labels.length - 2]}.${labels.last}';
    if (_compoundSuffixes.contains(lastTwo)) {
      if (labels.length < 3) return null;
      final brandLabel = labels[labels.length - 3];
      return ExtractedDomain(
        fullHost: host,
        rootDomain: '$brandLabel.$lastTwo',
        brandLabel: brandLabel,
        publicSuffix: lastTwo,
      );
    }

    final brandLabel = labels[labels.length - 2];
    final suffix = labels.last;
    return ExtractedDomain(
      fullHost: host,
      rootDomain: '$brandLabel.$suffix',
      brandLabel: brandLabel,
      publicSuffix: suffix,
    );
  }
}
