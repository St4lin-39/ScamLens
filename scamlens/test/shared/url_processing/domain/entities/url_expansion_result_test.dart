import 'package:flutter_test/flutter_test.dart';
import 'package:scamlens/shared/url_processing/domain/entities/url_expansion_result.dart';
import 'package:scamlens/shared/url_processing/domain/entities/url_processing_result.dart';

void main() {
  const target = 'https://destination.example/path';

  for (final status in UrlExpansionStatus.values) {
    test('represents $status without inventing destinations', () {
      final resolved = status == UrlExpansionStatus.resolved;
      final result = UrlExpansionResult(
        status: status,
        failureReason:
            status == UrlExpansionStatus.failed ||
                status == UrlExpansionStatus.blocked
            ? UrlExpansionFailureReason.unknown
            : null,
        redirectCount: resolved ? 1 : 0,
        verifiedDestination: resolved ? target : null,
        lastHttpStatus: resolved ? 200 : null,
      );
      expect(result.status, status);
      expect(result.announcedDestination, isNull);
      expect(result.verifiedDestination, resolved ? target : isNull);
    });
  }

  test(
    'resolved preserves observations and confirms only terminal destination',
    () {
      final result = UrlExpansionResult(
        status: UrlExpansionStatus.resolved,
        redirectCount: 2,
        announcedDestination: target,
        verifiedDestination: target,
        lastHttpStatus: 204,
      );
      expect(result.redirectCount, 2);
      expect(result.announcedDestination, target);
      expect(result.verifiedDestination, target);
      expect(result.lastHttpStatus, 204);
      expect(result.failureReason, isNull);
    },
  );

  test('timeout retains an announced destination without confirmation', () {
    final result = UrlExpansionResult(
      status: UrlExpansionStatus.timeout,
      redirectCount: 1,
      announcedDestination: target,
      lastHttpStatus: 302,
    );
    expect(result.announcedDestination, target);
    expect(result.verifiedDestination, isNull);
    expect(result.status, UrlExpansionStatus.timeout);
    expect(result.lastHttpStatus, 302);
  });

  for (final status in UrlExpansionStatus.values.where(
    (status) => status != UrlExpansionStatus.resolved,
  )) {
    test('$status cannot confirm a destination', () {
      expect(
        () => UrlExpansionResult(
          status: status,
          verifiedDestination: target,
          redirectCount: 1,
          lastHttpStatus: 200,
        ),
        throwsArgumentError,
      );
    });
  }

  test('resolved requires redirects, destination and terminal 2xx', () {
    for (final count in [0, 1]) {
      for (final destination in [null, target]) {
        for (final code in [null, 200, 302, 404]) {
          if (count == 1 && destination != null && code == 200) continue;
          expect(
            () => UrlExpansionResult(
              status: UrlExpansionStatus.resolved,
              redirectCount: count,
              verifiedDestination: destination,
              lastHttpStatus: code,
            ),
            throwsArgumentError,
          );
        }
      }
    }
  });

  test('validates counts, codes and absolute destination syntax', () {
    expect(
      () => UrlExpansionResult(
        status: UrlExpansionStatus.timeout,
        redirectCount: -1,
      ),
      throwsArgumentError,
    );
    for (final code in [0, 99, 600]) {
      expect(
        () => UrlExpansionResult(
          status: UrlExpansionStatus.timeout,
          lastHttpStatus: code,
        ),
        throwsArgumentError,
      );
    }
    for (final destination in [
      '',
      '/relative',
      'ftp://example.com',
      'https://',
      ' https://example.com',
      'https://example.com/a b',
    ]) {
      expect(
        () => UrlExpansionResult(
          status: UrlExpansionStatus.timeout,
          announcedDestination: destination,
        ),
        throwsArgumentError,
      );
    }
  });

  test('failed and blocked require typed reasons and preserve them', () {
    for (final status in [
      UrlExpansionStatus.failed,
      UrlExpansionStatus.blocked,
    ]) {
      expect(() => UrlExpansionResult(status: status), throwsArgumentError);
      for (final reason in UrlExpansionFailureReason.values) {
        expect(
          UrlExpansionResult(
            status: status,
            failureReason: reason,
          ).failureReason,
          reason,
        );
      }
    }
  });

  test('non-failure states reject contradictory failure reasons', () {
    for (final status in [
      UrlExpansionStatus.notAttempted,
      UrlExpansionStatus.noRedirect,
      UrlExpansionStatus.resolved,
    ]) {
      expect(
        () => UrlExpansionResult(
          status: status,
          redirectCount: status == UrlExpansionStatus.resolved ? 1 : 0,
          verifiedDestination: status == UrlExpansionStatus.resolved
              ? target
              : null,
          lastHttpStatus: status == UrlExpansionStatus.resolved ? 200 : null,
          failureReason: UrlExpansionFailureReason.connection,
        ),
        throwsArgumentError,
      );
    }
  });

  test('notAttempted and noRedirect cannot report a redirect', () {
    for (final status in [
      UrlExpansionStatus.notAttempted,
      UrlExpansionStatus.noRedirect,
    ]) {
      expect(
        () => UrlExpansionResult(status: status, redirectCount: 1),
        throwsArgumentError,
      );
      expect(
        () => UrlExpansionResult(status: status, announcedDestination: target),
        throwsArgumentError,
      );
    }
    expect(
      () => UrlExpansionResult(
        status: UrlExpansionStatus.notAttempted,
        lastHttpStatus: 200,
      ),
      throwsArgumentError,
    );
    expect(
      UrlExpansionResult(
        status: UrlExpansionStatus.noRedirect,
        lastHttpStatus: 200,
      ).verifiedDestination,
      isNull,
    );
  });

  test(
    'existing const constructor preserves separate raw and legacy output',
    () {
      const result = UrlProcessingResult(
        contentRaw: ' https://BIT.LY/a ',
        normalizedUrl: target,
        isUrl: true,
        wasShortened: true,
      );
      expect(result.contentRaw, ' https://BIT.LY/a ');
      expect(result.normalizedUrl, target);
      expect(result.expansion, isNull);
    },
  );

  test(
    'processing result accepts explicit observations without inferring them',
    () {
      final expansion = UrlExpansionResult(
        status: UrlExpansionStatus.notAttempted,
      );
      final result = UrlProcessingResult(
        contentRaw: 'bit.ly/a',
        normalizedUrl: 'https://bit.ly/a',
        isUrl: true,
        wasShortened: true,
        expansion: expansion,
      );
      expect(result.expansion, same(expansion));
      expect(result.expansion!.verifiedDestination, isNull);
    },
  );

  test('expansion observations expose no mutable fields', () {
    final result = UrlExpansionResult(status: UrlExpansionStatus.timeout);
    final dynamic dynamicResult = result;
    expect(
      () => dynamicResult.status = UrlExpansionStatus.resolved,
      throwsNoSuchMethodError,
    );
    expect(
      () => dynamicResult.failureReason = UrlExpansionFailureReason.tls,
      throwsNoSuchMethodError,
    );
    expect(() => dynamicResult.redirectCount = 1, throwsNoSuchMethodError);
    expect(
      () => dynamicResult.announcedDestination = target,
      throwsNoSuchMethodError,
    );
    expect(
      () => dynamicResult.verifiedDestination = target,
      throwsNoSuchMethodError,
    );
    expect(() => dynamicResult.lastHttpStatus = 200, throwsNoSuchMethodError);
  });
}
