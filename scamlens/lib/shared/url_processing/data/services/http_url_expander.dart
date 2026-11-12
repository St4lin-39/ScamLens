import 'dart:async';

import 'package:scamlens/core/config/url_config.dart';

import '../../domain/entities/url_expansion_result.dart';
import '../../domain/services/url_expander.dart';
import '../transport/expansion_http_session.dart';
import '../transport/expansion_http_session_factory.dart';
import '../transport/public_address_policy.dart';

/// Header-only expansion; all real connections use the secure session.
class HttpUrlExpander implements UrlExpander {
  static const expansionBudget = Duration(seconds: 12);
  static const requestLimit = UrlConfig.requestTimeout;
  static const maxRedirects = UrlConfig.maxRedirects;
  final ExpansionHttpSessionFactory sessionFactory;
  final PublicAddressPolicy policy;
  final Stopwatch Function() stopwatchFactory;

  HttpUrlExpander({
    this.sessionFactory = createExpansionHttpSession,
    this.policy = const PublicAddressPolicy(),
    this.stopwatchFactory = Stopwatch.new,
  });

  @override
  Future<UrlExpansionResult> expandUrl(String url) async {
    var redirects = 0;
    String? announced;
    int? lastStatus;
    var cancelled = false;
    ExpansionHttpSession? session;
    final watch = stopwatchFactory()..start();

    UrlExpansionResult result(
      UrlExpansionStatus status, {
      UrlExpansionFailureReason? reason,
      String? verified,
    }) => UrlExpansionResult(
      status: status,
      failureReason: reason,
      redirectCount: redirects,
      announcedDestination: announced,
      verifiedDestination: verified,
      lastHttpStatus: lastStatus,
    );

    UrlExpansionResult blocked(DestinationDecision decision) => result(
      UrlExpansionStatus.blocked,
      reason: switch (decision.reason) {
        DestinationBlockReason.unsupportedScheme =>
          UrlExpansionFailureReason.unsupportedScheme,
        DestinationBlockReason.invalidUri ||
        DestinationBlockReason.emptyHost ||
        DestinationBlockReason.ambiguousHost =>
          UrlExpansionFailureReason.invalidUrl,
        _ => UrlExpansionFailureReason.forbiddenDestination,
      },
    );

    Future<UrlExpansionResult> run() async {
      final initial = policy.validateUri(url);
      if (!initial.isAllowed) return blocked(initial);
      session = sessionFactory();
      var current = url.split('#').first;
      final visited = <String>{};

      Future<({int status, String? location})> request(String method) async {
        if (cancelled) {
          throw const ExpansionTransportException(
            ExpansionTransportFailure.cancelled,
          );
        }
        final remaining = expansionBudget - watch.elapsed;
        if (remaining <= Duration.zero) {
          throw const ExpansionTransportException(
            ExpansionTransportFailure.timeout,
          );
        }
        final response = await session!.send(
          method,
          current,
          timeout: remaining < requestLimit ? remaining : requestLimit,
        );
        try {
          if (cancelled) {
            throw const ExpansionTransportException(
              ExpansionTransportFailure.cancelled,
            );
          }
          final status = response.statusCode;
          lastStatus = status >= 100 && status <= 599 ? status : null;
          String? location;
          for (final header in response.headers.entries) {
            if (header.key.toLowerCase() == 'location') location = header.value;
          }
          return (status: status, location: location);
        } finally {
          // Cancel the stream, never read/drain a GET body.
          await response.close();
        }
      }

      while (!cancelled) {
        final uri = Uri.parse(current);
        // Canonicalize only the loop key; never decode/rebuild query parameters.
        final key = uri.normalizePath().removeFragment().toString();
        if (!visited.add(key)) {
          return result(
            UrlExpansionStatus.failed,
            reason: UrlExpansionFailureReason.redirectLoop,
          );
        }
        var response = await request('HEAD');
        if (cancelled) return result(UrlExpansionStatus.timeout);
        if (response.status == 405 ||
            response.status == 501 ||
            response.status >= 200 && response.status < 300) {
          response = await request('GET');
          if (cancelled) return result(UrlExpansionStatus.timeout);
        }
        if (const {301, 302, 303, 307, 308}.contains(response.status)) {
          final location = response.location;
          if (location == null ||
              location.isEmpty ||
              RegExp(r'[\x00-\x20\x7f\\]').hasMatch(location)) {
            return result(
              UrlExpansionStatus.failed,
              reason: UrlExpansionFailureReason.invalidLocation,
            );
          }
          final Uri next;
          try {
            next = uri.resolve(location).removeFragment();
          } on FormatException {
            return result(
              UrlExpansionStatus.failed,
              reason: UrlExpansionFailureReason.invalidLocation,
            );
          }
          // Domain stores only syntactically valid HTTP(S) announcements.
          // An announcement is not evidence that the destination was requested.
          if ((next.scheme == 'http' || next.scheme == 'https') &&
              next.host.isNotEmpty) {
            announced = next.toString();
          }
          // Validate raw absolute/network-path authorities too: Uri.resolve can
          // otherwise erase ambiguous host/port spellings before policy sees them.
          final rawAbsolute = location.startsWith('//')
              ? '${uri.scheme}:$location'
              : Uri.parse(location).hasScheme
              ? location
              : null;
          if (rawAbsolute != null) {
            final rawDecision = policy.validateUri(rawAbsolute);
            if (!rawDecision.isAllowed) return blocked(rawDecision);
          }
          final decision = policy.validateUri(next.toString());
          if (!decision.isAllowed) return blocked(decision);
          if (uri.scheme == 'https' && next.scheme == 'http') {
            return result(
              UrlExpansionStatus.blocked,
              reason: UrlExpansionFailureReason.insecureRedirect,
            );
          }
          if (visited.contains(next.normalizePath().toString())) {
            return result(
              UrlExpansionStatus.failed,
              reason: UrlExpansionFailureReason.redirectLoop,
            );
          }
          if (redirects == maxRedirects) {
            return result(
              UrlExpansionStatus.failed,
              reason: UrlExpansionFailureReason.redirectLimit,
            );
          }
          redirects++;
          current = next.toString();
          continue;
        }
        if (response.status >= 200 && response.status < 300) {
          return redirects == 0
              ? result(UrlExpansionStatus.noRedirect)
              : result(UrlExpansionStatus.resolved, verified: current);
        }
        return result(
          UrlExpansionStatus.failed,
          reason: UrlExpansionFailureReason.httpStatus,
        );
      }
      return result(UrlExpansionStatus.timeout);
    }

    try {
      return await run().timeout(
        expansionBudget,
        onTimeout: () {
          cancelled = true;
          session?.close();
          return result(UrlExpansionStatus.timeout);
        },
      );
    } on ExpansionTransportException catch (error) {
      return switch (error.failure) {
        ExpansionTransportFailure.blocked => blocked(
          DestinationDecision.blocked(
            error.blockReason ?? DestinationBlockReason.specialUseAddress,
          ),
        ),
        ExpansionTransportFailure.timeout => result(UrlExpansionStatus.timeout),
        ExpansionTransportFailure.cancelled => result(
          UrlExpansionStatus.cancelled,
        ),
        ExpansionTransportFailure.unsupportedPlatform => result(
          UrlExpansionStatus.unsupportedPlatform,
          reason: UrlExpansionFailureReason.securityPolicyUnavailable,
        ),
        ExpansionTransportFailure.dns => result(
          UrlExpansionStatus.failed,
          reason: UrlExpansionFailureReason.dns,
        ),
        ExpansionTransportFailure.connection => result(
          UrlExpansionStatus.failed,
          reason: UrlExpansionFailureReason.connection,
        ),
        ExpansionTransportFailure.tls => result(
          UrlExpansionStatus.failed,
          reason: UrlExpansionFailureReason.tls,
        ),
        _ => result(
          UrlExpansionStatus.failed,
          reason: UrlExpansionFailureReason.unknown,
        ),
      };
    } on TimeoutException {
      return result(UrlExpansionStatus.timeout);
    } catch (_) {
      return result(
        UrlExpansionStatus.failed,
        reason: UrlExpansionFailureReason.unknown,
      );
    } finally {
      cancelled = true;
      session?.close();
      watch.stop();
    }
  }
}
