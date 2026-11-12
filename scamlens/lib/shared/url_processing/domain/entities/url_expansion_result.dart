enum UrlExpansionStatus {
  notAttempted,
  resolved,
  noRedirect,
  failed,
  timeout,
  blocked,
  unsupportedPlatform,
  cancelled,
}

enum UrlExpansionFailureReason {
  unknown,
  dns,
  connection,
  tls,
  httpStatus,
  invalidLocation,
  redirectLoop,
  redirectLimit,
  invalidUrl,
  unsupportedScheme,
  forbiddenDestination,
  insecureRedirect,
  securityPolicyUnavailable,
}

/// Immutable observations from HTTP expansion, never a safety verdict.
///
/// Construction validates invariants in release builds too. This model does not
/// perform requests, DNS lookups or destination security checks.
final class UrlExpansionResult {
  final UrlExpansionStatus status;

  /// Required for failed/blocked; optional additional detail for other failures.
  final UrlExpansionFailureReason? failureReason;
  final int redirectCount;

  /// Last valid HTTP(S) Location resolved against the response URI.
  /// It need not have been requested and must not be presented as confirmed.
  final String? announcedDestination;

  /// Present only for resolved: a redirect chain ending in HTTP 2xx.
  /// Confirmation describes an HTTP observation, not site safety or reputation.
  final String? verifiedDestination;

  /// Last observed response code; it may belong to an intermediate response.
  final int? lastHttpStatus;

  factory UrlExpansionResult({
    required UrlExpansionStatus status,
    UrlExpansionFailureReason? failureReason,
    int redirectCount = 0,
    String? announcedDestination,
    String? verifiedDestination,
    int? lastHttpStatus,
  }) {
    void require(bool condition, String message) {
      if (!condition) throw ArgumentError(message);
    }

    require(redirectCount >= 0, 'redirectCount must be non-negative');
    require(
      lastHttpStatus == null || lastHttpStatus >= 100 && lastHttpStatus <= 599,
      'lastHttpStatus must be an HTTP status code',
    );
    for (final destination in [announcedDestination, verifiedDestination]) {
      if (destination == null) continue;
      final uri = Uri.tryParse(destination);
      require(
        destination.trim() == destination &&
            !RegExp(r'\s').hasMatch(destination) &&
            uri != null &&
            (uri.scheme == 'http' || uri.scheme == 'https') &&
            uri.host.isNotEmpty,
        'Destinations must be absolute HTTP(S) URLs',
      );
    }
    final resolved = status == UrlExpansionStatus.resolved;
    require(
      resolved
          ? redirectCount > 0 &&
                verifiedDestination != null &&
                lastHttpStatus != null &&
                lastHttpStatus >= 200 &&
                lastHttpStatus < 300
          : verifiedDestination == null,
      'Only resolved can confirm a destination; it requires redirects and 2xx',
    );
    if (status == UrlExpansionStatus.failed ||
        status == UrlExpansionStatus.blocked) {
      require(failureReason != null, 'Failure or blocking requires a reason');
    }
    if (resolved ||
        status == UrlExpansionStatus.noRedirect ||
        status == UrlExpansionStatus.notAttempted) {
      require(
        failureReason == null,
        'This status cannot have a failure reason',
      );
    }
    if (status == UrlExpansionStatus.noRedirect ||
        status == UrlExpansionStatus.notAttempted) {
      require(
        redirectCount == 0 && announcedDestination == null,
        'This status cannot contain redirects or an announced destination',
      );
    }
    if (status == UrlExpansionStatus.notAttempted) {
      require(lastHttpStatus == null, 'No HTTP response without an attempt');
    }
    return UrlExpansionResult._(
      status: status,
      failureReason: failureReason,
      redirectCount: redirectCount,
      announcedDestination: announcedDestination,
      verifiedDestination: verifiedDestination,
      lastHttpStatus: lastHttpStatus,
    );
  }

  const UrlExpansionResult._({
    required this.status,
    required this.failureReason,
    required this.redirectCount,
    required this.announcedDestination,
    required this.verifiedDestination,
    required this.lastHttpStatus,
  });
}
