import '../../../brand_impersonation/domain/entities/brand_impersonation_result.dart';
import '../../../brand_impersonation/domain/entities/official_brand.dart';
import '../../../brand_impersonation/domain/entities/official_brand_catalog.dart';
import '../../../brand_impersonation/domain/services/registrable_domain_extractor.dart';
import '../../../url_processing/domain/entities/url_expansion_result.dart';
import '../../../url_processing/domain/entities/url_processing_result.dart';
import '../../../url_processing/domain/services/web_url_recognizer.dart';
import '../entities/risk_evaluation_result.dart';
import '../entities/risk_evidence.dart';
import '../services/local_url_risk_analyzer.dart';
import '../../../analysis_progress/domain/analysis_progress.dart';

/// Local-only profile. Reuses US-07 observations without executing any I/O.
class EvaluateUrlRiskUseCase {
  final LocalUrlRiskAnalyzer localAnalyzer;

  EvaluateUrlRiskUseCase({LocalUrlRiskAnalyzer? localAnalyzer})
    : localAnalyzer = localAnalyzer ?? LocalUrlRiskAnalyzer();

  RiskEvaluationResult call(
    UrlProcessingResult input, {
    AnalysisProgressCallback? onProgress,
  }) {
    notifyAnalysisProgress(
      onProgress,
      const AnalysisProgress(
        AnalysisStage.evaluateRisk,
        AnalysisStageStatus.active,
      ),
    );
    try {
      final result = _evaluate(input);
      notifyAnalysisProgress(
        onProgress,
        const AnalysisProgress(
          AnalysisStage.evaluateRisk,
          AnalysisStageStatus.completed,
        ),
      );
      return result;
    } catch (_) {
      notifyAnalysisProgress(
        onProgress,
        const AnalysisProgress(
          AnalysisStage.evaluateRisk,
          AnalysisStageStatus.failed,
          reason: AnalysisProgressReason.error,
        ),
      );
      rethrow;
    }
  }

  RiskEvaluationResult _evaluate(UrlProcessingResult input) {
    final evidence = <RiskEvidence>[];
    final uncertainty = <RiskEvidenceId>[];
    final raw = input.contentRaw.trim();
    final expansion = input.expansion;
    final unresolved =
        input.wasShortened && expansion?.verifiedDestination == null;
    final target = unresolved ? null : expansion?.verifiedDestination ?? raw;

    void add(
      RiskEvidenceId id,
      String reason, {
      EvidenceSeverity severity = EvidenceSeverity.caution,
      bool uncertain = false,
      String? subject,
    }) {
      evidence.add(
        RiskEvidence(
          id: id,
          severity: severity,
          justification: reason,
          subject: subject ?? target ?? raw,
        ),
      );
      if (uncertain) uncertainty.add(id);
    }

    RiskEvaluationResult finish({bool notApplicable = false}) {
      final high = evidence.any((e) => e.severity == EvidenceSeverity.high);
      final caution = evidence.any(
        (e) => e.severity == EvidenceSeverity.caution,
      );
      final official = evidence.any(
        (e) => e.id == RiskEvidenceId.officialDomain,
      );
      return RiskEvaluationResult(
        level: high
            ? RiskLevel.red
            : caution || uncertainty.isNotEmpty || !official
            ? RiskLevel.yellow
            : RiskLevel.green,
        evidences: evidence,
        uncertaintyReasons: uncertainty,
        completeness: notApplicable
            ? RiskAnalysisCompleteness.notApplicable
            : uncertainty.isEmpty
            ? RiskAnalysisCompleteness.complete
            : RiskAnalysisCompleteness.partial,
        evaluatedUrl: notApplicable ? null : target,
      );
    }

    if (!input.isUrl) {
      add(
        RiskEvidenceId.invalidUrl,
        'El contenido no es una URL evaluable.',
        uncertain: true,
      );
      return finish(notApplicable: true);
    }
    if (expansion == null) {
      add(
        RiskEvidenceId.missingExpansionObservation,
        'No se dispone de observaciones de expansión.',
        uncertain: true,
      );
    } else if (!const {
      UrlExpansionStatus.notAttempted,
      UrlExpansionStatus.resolved,
      UrlExpansionStatus.noRedirect,
    }.contains(expansion.status)) {
      add(
        RiskEvidenceId.expansionIncomplete,
        'La expansión no se completó: ${expansion.status.name}'
        '${expansion.failureReason == null ? '' : ' (${expansion.failureReason!.name})'}.',
        uncertain: true,
      );
    }
    if (unresolved) {
      add(
        RiskEvidenceId.unresolvedShortener,
        'El enlace acortado no tiene un destino confirmado; '
        'no se atribuye al destino el análisis de marca del acortador.',
        uncertain: true,
      );
      // The entry itself can expose HTTP, but is not evaluated as the final host.
      if (raw.toLowerCase().startsWith('http://')) {
        add(
          RiskEvidenceId.explicitHttp,
          'El enlace de entrada utiliza HTTP.',
          subject: raw,
        );
      }
      return finish();
    }

    final value = target!;
    final uri = Uri.tryParse(
      WebUrlRecognizer.hasHttpScheme(value) ? value : 'https://$value',
    );
    if (uri == null ||
        uri.host.isEmpty ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        RegExp(r'[\x00-\x20\x7f\\]').hasMatch(value) ||
        // Validate host/path syntax without suppressing the credentials signal.
        !WebUrlRecognizer.isWebUrl(uri.replace(userInfo: '').toString())) {
      add(
        RiskEvidenceId.invalidUrl,
        'La estructura de la URL no permite evaluarla.',
        uncertain: true,
      );
      return finish();
    }
    final brand = input.brandImpersonation;
    final catalogBrands = brand?.evaluatedBrands ?? const <OfficialBrand>[];
    evidence.addAll(localAnalyzer.analyze(value, uri, catalogBrands));
    if (expansion?.verifiedDestination != null &&
        raw.toLowerCase().startsWith('http://') &&
        uri.scheme != 'http') {
      add(
        RiskEvidenceId.explicitHttp,
        'El enlace de entrada utiliza HTTP aunque el destino confirmado use HTTPS.',
        subject: raw,
      );
    }
    if (brand == null) {
      add(
        RiskEvidenceId.brandAnalysisMissing,
        'El análisis de marca no está disponible.',
        uncertain: true,
      );
      return finish();
    }
    switch (brand.catalogStatus) {
      case BrandCatalogStatus.available:
        break;
      case BrandCatalogStatus.stale:
        add(
          RiskEvidenceId.catalogStale,
          'Se utilizó un catálogo de marcas vencido.',
          uncertain: true,
        );
      case BrandCatalogStatus.unavailable:
        add(
          RiskEvidenceId.catalogUnavailable,
          'No se pudo consultar el catálogo de marcas.',
          uncertain: true,
        );
      case BrandCatalogStatus.unknown:
        add(
          RiskEvidenceId.catalogUnknown,
          'No se conoce la disponibilidad del catálogo.',
          uncertain: true,
        );
    }
    final extracted = RegistrableDomainExtractor().extract(value);
    final matchesTarget =
        extracted != null && extracted.rootDomain == brand.evaluatedRootDomain;
    if (brand.status != BrandMatchStatus.notApplicable && !matchesTarget) {
      add(
        RiskEvidenceId.brandTargetMismatch,
        'El resultado de marca no corresponde al dominio evaluado.',
        uncertain: true,
      );
      return finish();
    }
    switch (brand.status) {
      case BrandMatchStatus.officialVerified:
        final officialHost = brand.matchedBrand?.officialDomain.toLowerCase();
        if (officialHost == null ||
            !(uri.host.toLowerCase() == officialHost ||
                uri.host.toLowerCase().endsWith('.$officialHost'))) {
          add(
            RiskEvidenceId.brandTargetMismatch,
            'La coincidencia oficial no acredita este host.',
            uncertain: true,
          );
        } else {
          add(
            RiskEvidenceId.officialDomain,
            'El dominio pertenece a ${brand.matchedBrand!.entityName} según el catálogo. '
            'Esto no garantiza la seguridad del contenido.',
            severity: EvidenceSeverity.information,
          );
        }
      case BrandMatchStatus.suspectedImpersonation:
        add(
          RiskEvidenceId.brandImpersonation,
          brand.heuristicDetail?.technicalEvidence ??
              'US-07 detectó similitud con un dominio oficial.',
          severity:
              brand.editDistance == 1 &&
                  brand.catalogStatus == BrandCatalogStatus.available
              ? EvidenceSeverity.high
              : EvidenceSeverity.caution,
        );
      case BrandMatchStatus.noMatch:
      case BrandMatchStatus.notApplicable:
        add(
          RiskEvidenceId.unknownDomain,
          'No se ha reconocido este destino como dominio oficial; no significa que sea malicioso.',
        );
    }
    return finish();
  }
}
