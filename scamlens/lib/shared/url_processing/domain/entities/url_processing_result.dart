import '../../../brand_impersonation/domain/entities/brand_impersonation_result.dart';
import '../../../ioc_verification/domain/entities/ioc_check_result.dart';
import 'url_expansion_result.dart';

class UrlProcessingResult {
  /// Original content supplied by the caller, independent of normalizedUrl.
  final String contentRaw;

  /// Normalized input for presentation, never an expansion destination.
  final String normalizedUrl;
  final bool isUrl;
  final bool wasShortened;

  /// Null means the legacy producer supplied no typed expansion observations.
  /// It must not be interpreted as notAttempted, failure or success.
  final UrlExpansionResult? expansion;

  /// Heuristic brand impersonation analysis (Levenshtein against official_brand).
  final BrandImpersonationResult? brandImpersonation;

  /// Verification against confirmed Indicators of Compromise (Supabase + Safe Browsing).
  final IocCheckResult? iocCheck;

  const UrlProcessingResult({
    required this.contentRaw,
    required this.normalizedUrl,
    required this.isUrl,
    required this.wasShortened,
    this.expansion,
    this.brandImpersonation,
    this.iocCheck,
  });
}
