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
        'El enlace utiliza HTTP sin cifrado HTTPS.',
      );
    }
    if (host.contains(':') || RegExp(r'^[0-9.]+$').hasMatch(host)) {
      add(
        RiskEvidenceId.ipHost,
        'El host es una dirección IP, no un dominio de marca.',
      );
    }
    if (uri.userInfo.isNotEmpty) {
      add(
        RiskEvidenceId.embeddedCredentials,
        'La URL contiene credenciales antes del host; pueden confundir sobre el destino.',
      );
    }
    if (uri.hasPort && uri.port != 80 && uri.port != 443) {
      add(
        RiskEvidenceId.unusualPort,
        'El enlace utiliza un puerto no habitual.',
      );
    }
    if (url.length > 2048) {
      add(
        RiskEvidenceId.longUrl,
        'La URL supera 2048 caracteres; es un indicio débil.',
      );
    }
    if (host.split('.').any((label) => label.startsWith('xn--')) ||
        host.codeUnits.any((unit) => unit > 127)) {
      add(
        RiskEvidenceId.internationalizedHost,
        'El host internacionalizado requiere comprobaciones adicionales de identidad.',
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
        'El host contiene cuatro o más subdominios; es un indicio débil.',
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
          'El dominio oficial ${official.rootDomain} aparece como subdominio '
          'de otro dominio (${extracted.rootDomain}).',
          high: true,
        );
      } else if (official.brandLabel.length >= 5 &&
          subdomains.contains(official.brandLabel)) {
        add(
          RiskEvidenceId.brandLabelInSubdomain,
          'El nombre de ${brand.entityName} aparece en un subdominio ajeno; '
          'puede tener un uso legítimo y requiere precaución.',
        );
      }
    }
    return evidence;
  }
}
