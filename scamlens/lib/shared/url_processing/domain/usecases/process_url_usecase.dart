import '../../../brand_impersonation/domain/entities/brand_impersonation_result.dart';
import '../../../brand_impersonation/domain/usecases/detect_brand_impersonation_usecase.dart';
import '../../../ioc_verification/domain/entities/ioc_check_result.dart';
import '../../../ioc_verification/domain/usecases/verify_ioc_usecase.dart';
import '../entities/url_processing_result.dart';
import '../entities/url_expansion_result.dart';
import '../services/url_expander.dart';
import '../services/url_normalizer.dart';
import '../services/web_url_recognizer.dart';
import '../../../analysis_progress/domain/analysis_progress.dart';
import '../../../brand_impersonation/domain/entities/official_brand_catalog.dart';

class ProcessUrlUseCase {
  final UrlNormalizer normalizer;
  final UrlExpander expander;
  final DetectBrandImpersonationUseCase? detectBrandImpersonationUseCase;
  final VerifyIocUseCase? verifyIocUseCase;

  ProcessUrlUseCase({
    required this.normalizer,
    required this.expander,
    this.detectBrandImpersonationUseCase,
    this.verifyIocUseCase,
  });

  /// Rejects empty content; the caller supplies any presentation-specific message.
  Future<UrlProcessingResult> call(
    String content, {
    AnalysisProgressCallback? onProgress,
  }) async {
    void report(
      AnalysisStage stage,
      AnalysisStageStatus status, [
      AnalysisProgressReason? reason,
    ]) => notifyAnalysisProgress(
      onProgress,
      AnalysisProgress(stage, status, reason: reason),
    );
    report(AnalysisStage.normalizeUrl, AnalysisStageStatus.active);
    final raw = content.trim();
    if (raw.isEmpty) {
      report(
        AnalysisStage.normalizeUrl,
        AnalysisStageStatus.failed,
        AnalysisProgressReason.error,
      );
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
        report(AnalysisStage.normalizeUrl, AnalysisStageStatus.completed);
      } catch (_) {
        report(
          AnalysisStage.normalizeUrl,
          AnalysisStageStatus.failed,
          AnalysisProgressReason.error,
        );
        normalizedUrl = raw;
        expansion = UrlExpansionResult(
          status: UrlExpansionStatus.failed,
          failureReason: UrlExpansionFailureReason.unknown,
        );
      }
      if (wasShortened) {
        report(AnalysisStage.expandShortener, AnalysisStageStatus.active);
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
        final (status, reason) = switch (expansion.status) {
          UrlExpansionStatus.resolved || UrlExpansionStatus.noRedirect => (
            AnalysisStageStatus.completed,
            null,
          ),
          UrlExpansionStatus.unsupportedPlatform => (
            AnalysisStageStatus.unavailable,
            AnalysisProgressReason.unsupportedPlatform,
          ),
          UrlExpansionStatus.timeout => (
            AnalysisStageStatus.failed,
            AnalysisProgressReason.timeout,
          ),
          UrlExpansionStatus.blocked => (
            AnalysisStageStatus.failed,
            AnalysisProgressReason.blocked,
          ),
          UrlExpansionStatus.cancelled => (
            AnalysisStageStatus.failed,
            AnalysisProgressReason.cancelled,
          ),
          UrlExpansionStatus.notAttempted => (
            AnalysisStageStatus.skipped,
            AnalysisProgressReason.notApplicable,
          ),
          UrlExpansionStatus.failed => (
            AnalysisStageStatus.failed,
            AnalysisProgressReason.error,
          ),
        };
        report(AnalysisStage.expandShortener, status, reason);
      }
    } else {
      report(AnalysisStage.normalizeUrl, AnalysisStageStatus.completed);
    }

    BrandImpersonationResult? brandImpersonation;
    if (isUrl && detectBrandImpersonationUseCase != null) {
      report(AnalysisStage.brandCheck, AnalysisStageStatus.active);
      final targetToEvaluate = expansion.verifiedDestination ?? normalizedUrl;
      try {
        brandImpersonation = await detectBrandImpersonationUseCase!(
          targetToEvaluate,
        );
        final result = brandImpersonation;
        final (status, reason) = result.status == BrandMatchStatus.notApplicable
            ? (
                AnalysisStageStatus.skipped,
                AnalysisProgressReason.notApplicable,
              )
            : switch (result.catalogStatus) {
                BrandCatalogStatus.available => (
                  AnalysisStageStatus.completed,
                  null,
                ),
                BrandCatalogStatus.stale => (
                  AnalysisStageStatus.unavailable,
                  AnalysisProgressReason.catalogStale,
                ),
                BrandCatalogStatus.unavailable => (
                  AnalysisStageStatus.unavailable,
                  AnalysisProgressReason.catalogUnavailable,
                ),
                BrandCatalogStatus.unknown => (
                  AnalysisStageStatus.unavailable,
                  AnalysisProgressReason.catalogUnknown,
                ),
              };
        report(AnalysisStage.brandCheck, status, reason);
      } catch (_) {
        brandImpersonation = null;
        report(
          AnalysisStage.brandCheck,
          AnalysisStageStatus.failed,
          AnalysisProgressReason.error,
        );
      }
    } else {
      report(
        AnalysisStage.brandCheck,
        AnalysisStageStatus.skipped,
        isUrl
            ? AnalysisProgressReason.notConfigured
            : AnalysisProgressReason.notApplicable,
      );
    }

    IocCheckResult? iocCheck;
    if (verifyIocUseCase != null) {
      if (!isUrl) {
        report(
          AnalysisStage.iocCheck,
          AnalysisStageStatus.skipped,
          AnalysisProgressReason.notApplicable,
        );
      } else {
        report(AnalysisStage.iocCheck, AnalysisStageStatus.active);
        try {
          final protectedDomains =
              brandImpersonation?.evaluatedBrands
                  .map((b) => b.officialDomain)
                  .toList(growable: false) ??
              const <String>[];
          iocCheck = await verifyIocUseCase!(
            normalizedUrl: normalizedUrl,
            verifiedDestination: expansion.verifiedDestination,
            protectedDomains: protectedDomains,
          );
          final (status, reason) = iocCheck.status == IocCheckStatus.notApplicable
              ? (
                  AnalysisStageStatus.skipped,
                  AnalysisProgressReason.notApplicable,
                )
              : switch (iocCheck.sourceAvailability) {
                  IocSourceAvailability.available => (
                    AnalysisStageStatus.completed,
                    null,
                  ),
                  IocSourceAvailability.partial => (
                    AnalysisStageStatus.completed,
                    null,
                  ),
                  IocSourceAvailability.unavailable => (
                    AnalysisStageStatus.unavailable,
                    AnalysisProgressReason.catalogUnavailable,
                  ),
                  IocSourceAvailability.notConfigured => (
                    AnalysisStageStatus.skipped,
                    AnalysisProgressReason.notConfigured,
                  ),
                };
          report(AnalysisStage.iocCheck, status, reason);
        } catch (_) {
          iocCheck = null;
          report(
            AnalysisStage.iocCheck,
            AnalysisStageStatus.failed,
            AnalysisProgressReason.error,
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
      brandImpersonation: brandImpersonation,
      iocCheck: iocCheck,
    );
  }
}
