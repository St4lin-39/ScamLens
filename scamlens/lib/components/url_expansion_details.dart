import 'package:flutter/material.dart';
import 'package:scamlens/shared/url_processing/domain/entities/url_expansion_result.dart';
import 'package:scamlens/theme/app_theme.dart';

/// Presentation only. Announced destinations are deliberately not displayed.
class UrlExpansionDetails extends StatelessWidget {
  final UrlExpansionResult? expansion;

  const UrlExpansionDetails({super.key, required this.expansion});

  @override
  Widget build(BuildContext context) {
    final result = expansion;
    if (result == null) return const SizedBox.shrink();
    final message = switch (result.status) {
      UrlExpansionStatus.resolved || UrlExpansionStatus.notAttempted => null,
      UrlExpansionStatus.noRedirect => 'No HTTP redirect was detected.',
      UrlExpansionStatus.timeout => 'Could not complete the check in time.',
      UrlExpansionStatus.failed => 'An error occurred while checking the link.',
      UrlExpansionStatus.blocked =>
        'The check was blocked by a network security restriction.',
      UrlExpansionStatus.unsupportedPlatform =>
        'URL expansion is unavailable on this platform.',
      UrlExpansionStatus.cancelled => 'The operation was cancelled.',
    };
    final stateLabel = switch (result.status) {
      UrlExpansionStatus.resolved => 'Destination confirmed via HTTP',
      UrlExpansionStatus.noRedirect => 'No HTTP redirect',
      UrlExpansionStatus.timeout => 'Timed out',
      UrlExpansionStatus.failed => 'Check failed',
      UrlExpansionStatus.blocked => 'Blocked by network policy',
      UrlExpansionStatus.unsupportedPlatform => 'Unavailable on this platform',
      UrlExpansionStatus.cancelled => 'Cancelled',
      UrlExpansionStatus.notAttempted => 'Expansion not requested',
    };
    const detailStyle = TextStyle(color: AppColors.textSecondary, fontSize: 12);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (message != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
        ExpansionTile(
          key: ObjectKey(result),
          initiallyExpanded: false,
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.zero,
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          dense: true,
          shape: const Border(),
          collapsedShape: const Border(),
          iconColor: AppColors.textSecondary,
          collapsedIconColor: AppColors.textSecondary,
          title: const Text('Processing details', style: detailStyle),
          children: [
            Text('Status: $stateLabel', style: detailStyle),
            if (result.status != UrlExpansionStatus.notAttempted &&
                result.status != UrlExpansionStatus.unsupportedPlatform)
              Text(
                'Redirects: ${result.redirectCount}',
                style: detailStyle,
              ),
            if (result.lastHttpStatus != null)
              Text('HTTP status: ${result.lastHttpStatus}', style: detailStyle),
            if (result.failureReason != null)
              Text(
                'Reason: ${_reason(result.failureReason!)}',
                style: detailStyle,
              ),
          ],
        ),
      ],
    );
  }

  static String _reason(UrlExpansionFailureReason reason) => switch (reason) {
    UrlExpansionFailureReason.unknown => 'Unknown reason.',
    UrlExpansionFailureReason.dns => 'Could not resolve the server hostname.',
    UrlExpansionFailureReason.connection =>
      'Could not establish a connection.',
    UrlExpansionFailureReason.tls => 'Could not validate the TLS connection.',
    UrlExpansionFailureReason.httpStatus =>
      'The server response did not allow completing the check.',
    UrlExpansionFailureReason.invalidLocation =>
      'The response did not provide a valid destination.',
    UrlExpansionFailureReason.redirectLoop =>
      'A redirect loop was detected.',
    UrlExpansionFailureReason.redirectLimit =>
      'The redirect limit was reached.',
    UrlExpansionFailureReason.invalidUrl =>
      'The address format is not supported.',
    UrlExpansionFailureReason.unsupportedScheme =>
      'The destination protocol is not supported.',
    UrlExpansionFailureReason.forbiddenDestination =>
      'The destination is not allowed by network policy.',
    UrlExpansionFailureReason.insecureRedirect =>
      'An HTTPS to HTTP downgrade was rejected.',
    UrlExpansionFailureReason.securityPolicyUnavailable =>
      'This platform cannot enforce the network policy.',
  };
}
