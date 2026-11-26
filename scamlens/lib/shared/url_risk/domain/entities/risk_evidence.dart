enum EvidenceSeverity { information, caution, high }

/// Stable identifiers are independent of the readable Spanish explanations.
enum RiskEvidenceId {
  evaluationUnavailable,
  officialDomain,
  unknownDomain,
  brandImpersonation,
  deceptiveBrandSubdomain,
  brandLabelInSubdomain,
  explicitHttp,
  ipHost,
  embeddedCredentials,
  unusualPort,
  longUrl,
  manySubdomains,
  internationalizedHost,
  invalidUrl,
  missingExpansionObservation,
  unresolvedShortener,
  expansionIncomplete,
  catalogUnavailable,
  catalogStale,
  catalogUnknown,
  brandAnalysisMissing,
  brandTargetMismatch,
  confirmedIoc,
  iocCheckPartial,
  iocCheckUnavailable,
}

class RiskEvidence {
  final RiskEvidenceId id;
  final EvidenceSeverity severity;
  final String justification;

  /// The URL to which this observation applies; never an announced destination.
  final String subject;

  const RiskEvidence({
    required this.id,
    required this.severity,
    required this.justification,
    required this.subject,
  });
}
