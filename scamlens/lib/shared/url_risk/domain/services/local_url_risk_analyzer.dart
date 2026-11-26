import '../../../brand_impersonation/domain/entities/official_brand.dart';
import '../../../brand_impersonation/domain/services/registrable_domain_extractor.dart';
import '../entities/risk_evidence.dart';

/// Pure observations: no HTTP, DNS, catalog lookup or Levenshtein calculation.
class LocalUrlRiskAnalyzer {
  final RegistrableDomainExtractor domainExtractor;

  LocalUrlRiskAnalyzer({RegistrableDomainExtractor? domainExtractor})
    : domainExtractor = domainExtractor ?? RegistrableDomainExtractor();

  List<RiskEvidence> analyze(
    String url,
    Uri uri,
    Iterable<OfficialBrand> brands,
  ) {
    final evidence = <RiskEvidence>[];
    void add(RiskEvidenceId id, String message, {bool high = false}) {
      evidence.add(
        RiskEvidence(
          id: id,
          severity: high ? EvidenceSeverity.high : EvidenceSeverity.caution,
          justification: message,
          subject: url,
        ),
      );
    }

    final host = uri.host.toLowerCase();
    if (uri.scheme == 'http') {
      add(
        RiskEvidenceId.explicitHttp,
        'The link uses unencrypted HTTP instead of HTTPS.',
      );
    }
    if (host.contains(':') || RegExp(r'^[0-9.]+$').hasMatch(host)) {
      add(
        RiskEvidenceId.ipHost,
        'The host is an IP address rather than a brand domain.',
      );
    }
    if (uri.userInfo.isNotEmpty) {
      add(
        RiskEvidenceId.embeddedCredentials,
        'The URL contains embedded credentials before the host, which can obscure the destination.',
      );
    }
    if (uri.hasPort && uri.port != 80 && uri.port != 443) {
      add(
        RiskEvidenceId.unusualPort,
        'The link uses a non-standard port.',
      );
    }
    if (url.length > 2048) {
      add(
        RiskEvidenceId.longUrl,
        'The URL exceeds 2048 characters, which is a weak risk indicator.',
      );
    }
    if (host.split('.').any((label) => label.startsWith('xn--')) ||
        host.codeUnits.any((unit) => unit > 127)) {
      add(
        RiskEvidenceId.internationalizedHost,
        'Internationalized hostnames require additional identity verification.',
      );
    }

    final extracted = domainExtractor.extract(url);
    if (extracted == null) return evidence;
    final labels = host.split('.');
    final rootLabels = extracted.rootDomain.split('.').length;
    final subdomains = labels.take(labels.length - rootLabels).toList();
    if (subdomains.length >= 4) {
      add(
        RiskEvidenceId.manySubdomains,
        'The host contains four or more subdomains, which is a weak risk indicator.',
      );
    }
    for (final brand in brands.where((brand) => brand.active)) {
      final official = domainExtractor.extract(brand.officialDomain);
      if (official == null || official.rootDomain == extracted.rootDomain) {
        continue;
      }
      // Whole label sequences only: never substring-match a short brand name.
      final subdomainText = '.${subdomains.join('.')}.';
      final officialSequence = '.${official.rootDomain}.';
      if (subdomainText.contains(officialSequence)) {
        add(
          RiskEvidenceId.deceptiveBrandSubdomain,
          'The official domain ${official.rootDomain} appears as a subdomain '
          'of another domain (${extracted.rootDomain}).',
          high: true,
        );
      } else if (official.brandLabel.length >= 5 &&
          subdomains.contains(official.brandLabel)) {
        add(
          RiskEvidenceId.brandLabelInSubdomain,
          'The name of ${brand.entityName} appears in a foreign subdomain; '
          'it may be legitimate but requires caution.',
        );
      }
    }
    return evidence;
  }
}
