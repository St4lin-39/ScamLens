import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:scamlens/shared/url_processing/data/services/http_url_expander.dart';
import 'package:scamlens/shared/url_processing/data/transport/expansion_http_session.dart';
import 'package:scamlens/shared/url_processing/data/transport/public_address_policy.dart';
import 'package:scamlens/shared/url_processing/domain/entities/url_expansion_result.dart';
import 'package:scamlens/shared/url_processing/domain/services/url_normalizer.dart';
import 'package:scamlens/shared/url_processing/domain/usecases/process_url_usecase.dart';

const source = 'https://bit.ly/a';
const target = 'https://destination.scamlens.net/path';

class _Response implements ExpansionHttpResponse {
  @override
  final int statusCode;
  @override
  final Map<String, String> headers;
  bool closed = false;
  _Response(this.statusCode, [String? location])
    : headers = location == null ? {} : {'location': location};
  @override
  Stream<List<int>> get body =>
      throw StateError('Expansion must never read a body');
  @override
  Future<void> close() async {
    closed = true;
  }
}

class _Session implements ExpansionHttpSession {
  final Future<_Response> Function(String method, String url) respond;
  final requests = <({String method, String url, Duration timeout})>[];
  final responses = <_Response>[];
  bool closed = false;
  _Session(this.respond);
  @override
  Future<ExpansionHttpResponse> send(
    String method,
    String url, {
    Duration timeout = const Duration(seconds: 4),
  }) async {
    if (closed) throw StateError('Request after session close');
    expectSync(responses.every((response) => response.closed), isTrue);
    requests.add((method: method, url: url, timeout: timeout));
    final response = await respond(method, url);
    responses.add(response);
    return response;
  }

  @override
  void close() {
    closed = true;
  }
}

class _Clock implements Stopwatch {
  @override
  Duration elapsed = Duration.zero;
  @override
  void start() {}
  @override
  void stop() {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  for (final status in [301, 302, 303, 307, 308]) {
    test(
      'HEAD follows $status, then verifies terminal response with GET',
      () async {
        final session = _Session(
          (method, url) async =>
              url == source ? _Response(status, target) : _Response(200),
        );
        final result = await HttpUrlExpander(sessionFactory: () => session)
            .expandUrl(source);
        expect(result.status, UrlExpansionStatus.resolved);
        expect(result.redirectCount, 1);
        expect(result.announcedDestination, target);
        expect(result.verifiedDestination, target);
        expect(result.lastHttpStatus, 200);
        expect(session.requests.map((r) => (r.method, r.url)), [
          ('HEAD', source),
          ('HEAD', target),
          ('GET', target),
        ]);
        expect(session.responses.every((r) => r.closed), isTrue);
        expect(session.closed, isTrue);
      },
    );
  }

  for (final status in [200, 204, 405, 501]) {
    test('HEAD $status falls back to GET exactly once', () async {
      // Stop at target to distinguish fallback from any retry at source.
      final session = _Session((method, url) async {
        if (url == target) return _Response(404);
        return method == 'HEAD' ? _Response(status) : _Response(302, target);
      });
      final result = await HttpUrlExpander(sessionFactory: () => session)
          .expandUrl(source);
      expect(session.requests.map((r) => (r.method, r.url)), [
        ('HEAD', source),
        ('GET', source),
        ('HEAD', target),
      ]);
      expect(result.status, UrlExpansionStatus.failed);
      expect(result.failureReason, UrlExpansionFailureReason.httpStatus);
      expect(result.announcedDestination, target);
      expect(result.verifiedDestination, isNull);
    });
  }

  test(
    '200 without redirects is noRedirect, never a verified destination',
    () async {
      final session = _Session((_, _) async => _Response(200, '/ignored'));
      final result = await HttpUrlExpander(sessionFactory: () => session)
          .expandUrl(source);
      expect(result.status, UrlExpansionStatus.noRedirect);
      expect(result.redirectCount, 0);
      expect(result.announcedDestination, isNull);
      expect(result.verifiedDestination, isNull);
      expect(session.requests.map((r) => r.method), ['HEAD', 'GET']);
    },
  );

  for (final status in [300, 304, 400, 401, 404, 429, 500, 503]) {
    test(
      'HEAD $status fails without GET or following irrelevant Location',
      () async {
        final session = _Session((_, _) async => _Response(status, target));
        final result = await HttpUrlExpander(sessionFactory: () => session)
            .expandUrl(source);
        expect(result.status, UrlExpansionStatus.failed);
        expect(result.failureReason, UrlExpansionFailureReason.httpStatus);
        expect(result.lastHttpStatus, status);
        expect(result.verifiedDestination, isNull);
        expect(session.requests, hasLength(1));
        expect(session.closed, isTrue);
      },
    );
  }

  test('failed GET does not trigger a second GET', () async {
    final session = _Session(
      (method, _) async => _Response(method == 'HEAD' ? 405 : 501),
    );
    final result = await HttpUrlExpander(sessionFactory: () => session)
        .expandUrl(source);
    expect(result.failureReason, UrlExpansionFailureReason.httpStatus);
    expect(session.requests.map((r) => r.method), ['HEAD', 'GET']);
  });

  test(
    'relative chain preserves repeated query parameters and ignores fragments',
    () async {
      const input =
          'https://bit.ly/folder/a?z=2&utm_source=x&id=1&id=2&a=%2F#first';
      const first = 'https://bit.ly/folder/a?z=2&utm_source=x&id=1&id=2&a=%2F';
      const second = 'https://bit.ly/target?b=2&b=1&utm_source=y';
      const last = '$target?b=2&b=1';
      final session = _Session(
        (_, url) async => url == first
            ? _Response(302, '../target?b=2&b=1&utm_source=y#next')
            : url == second
            ? _Response(307, '$last#end')
            : _Response(204),
      );
      final result = await HttpUrlExpander(sessionFactory: () => session)
          .expandUrl(input);
      expect(session.requests.map((r) => r.url), [first, second, last, last]);
      expect(result.status, UrlExpansionStatus.resolved);
      expect(result.verifiedDestination, last);
      expect(result.redirectCount, 2);
    },
  );

  for (final location in [null, '', '/a b', '/a\\b', 'https://[invalid']) {
    test('invalid Location=$location is explicit failure', () async {
      final session = _Session((_, _) async => _Response(302, location));
      final result = await HttpUrlExpander(sessionFactory: () => session)
          .expandUrl(source);
      expect(result.failureReason, UrlExpansionFailureReason.invalidLocation);
      expect(result.verifiedDestination, isNull);
      expect(session.requests, hasLength(1));
      expect(session.responses.single.closed, isTrue);
    });
  }

  for (final location in [
    source,
    '$source#part',
    'https://BIT.LY:443/a',
    '/folder/../a',
  ]) {
    test('detects equivalent self loop: $location', () async {
      final session = _Session((_, _) async => _Response(302, location));
      final result = await HttpUrlExpander(sessionFactory: () => session)
          .expandUrl(source);
      expect(result.failureReason, UrlExpansionFailureReason.redirectLoop);
      expect(result.verifiedDestination, isNull);
      expect(session.requests, hasLength(1));
    });
  }

  test('detects multi-URL loop', () async {
    final session = _Session(
      (_, url) async => _Response(302, url == source ? target : source),
    );
    final result = await HttpUrlExpander(sessionFactory: () => session)
        .expandUrl(source);
    expect(result.failureReason, UrlExpansionFailureReason.redirectLoop);
    expect(result.redirectCount, 1);
    expect(session.requests, hasLength(2));
  });

  for (final terminal in [true, false]) {
    test(
      'five jumps ${terminal ? 'verifies last destination' : 'stops before sixth destination'}',
      () async {
        var step = 0;
        final session = _Session((method, _) async {
          if (terminal && step == 5) return _Response(200);
          step++;
          return _Response(302, '/step$step');
        });
        final result = await HttpUrlExpander(sessionFactory: () => session)
            .expandUrl(source);
        expect(result.redirectCount, 5);
        expect(
          result.status,
          terminal ? UrlExpansionStatus.resolved : UrlExpansionStatus.failed,
        );
        expect(
          result.verifiedDestination,
          terminal ? 'https://bit.ly/step5' : isNull,
        );
        expect(
          result.announcedDestination,
          'https://bit.ly/step${terminal ? 5 : 6}',
        );
        expect(session.requests, hasLength(terminal ? 7 : 6));
        if (!terminal) {
          expect(result.failureReason, UrlExpansionFailureReason.redirectLimit);
        }
      },
    );
  }

  for (final entry in {
    'http://destination.scamlens.net/path':
        UrlExpansionFailureReason.insecureRedirect,
    'https://127.0.0.1/path': UrlExpansionFailureReason.forbiddenDestination,
    'https://printer.local/path':
        UrlExpansionFailureReason.forbiddenDestination,
    'file:///secret': UrlExpansionFailureReason.unsupportedScheme,
    'javascript:alert(1)': UrlExpansionFailureReason.unsupportedScheme,
  }.entries) {
    test('blocks redirect ${entry.key} before requesting it', () async {
      final session = _Session((_, _) async => _Response(302, entry.key));
      final result = await HttpUrlExpander(sessionFactory: () => session)
          .expandUrl(source);
      expect(result.status, UrlExpansionStatus.blocked);
      expect(result.failureReason, entry.value);
      expect(result.verifiedDestination, isNull);
      expect(session.requests, hasLength(1));
    });
  }

  test('invalid initial URI never creates a session', () async {
    final expander = HttpUrlExpander(
      sessionFactory: () => throw StateError('must not create'),
    );
    for (final url in [
      'https://localhost',
      'ftp://bit.ly/a',
      'https://user:pass@bit.ly/a',
    ]) {
      expect(
        (await expander.expandUrl(url)).status,
        UrlExpansionStatus.blocked,
      );
    }
  });

  for (final entry in {
    ExpansionTransportFailure.dns: (
      UrlExpansionStatus.failed,
      UrlExpansionFailureReason.dns,
    ),
    ExpansionTransportFailure.connection: (
      UrlExpansionStatus.failed,
      UrlExpansionFailureReason.connection,
    ),
    ExpansionTransportFailure.tls: (
      UrlExpansionStatus.failed,
      UrlExpansionFailureReason.tls,
    ),
    ExpansionTransportFailure.timeout: (UrlExpansionStatus.timeout, null),
    ExpansionTransportFailure.cancelled: (UrlExpansionStatus.cancelled, null),
    ExpansionTransportFailure.unsupportedPlatform: (
      UrlExpansionStatus.unsupportedPlatform,
      UrlExpansionFailureReason.securityPolicyUnavailable,
    ),
    ExpansionTransportFailure.blocked: (
      UrlExpansionStatus.blocked,
      UrlExpansionFailureReason.forbiddenDestination,
    ),
  }.entries) {
    test('preserves transport ${entry.key} after a redirect', () async {
      final session = _Session((_, url) async {
        if (url == source) return _Response(302, target);
        throw ExpansionTransportException(
          entry.key,
          blockReason: DestinationBlockReason.specialUseAddress,
        );
      });
      final result = await HttpUrlExpander(sessionFactory: () => session)
          .expandUrl(source);
      expect(result.status, entry.value.$1);
      expect(result.failureReason, entry.value.$2);
      expect(result.announcedDestination, target);
      expect(result.verifiedDestination, isNull);
      expect(result.lastHttpStatus, 302);
      expect(session.closed, isTrue);
    });
  }

  test('unknown transport/factory failures remain identifiable', () async {
    final result = await HttpUrlExpander(
      sessionFactory: () => throw StateError('factory'),
    ).expandUrl(source);
    expect(result.status, UrlExpansionStatus.failed);
    expect(result.failureReason, UrlExpansionFailureReason.unknown);
  });

  test('caps request timeout by four seconds and remaining budget', () async {
    final clock = _Clock();
    final session = _Session((_, url) async {
      clock.elapsed = const Duration(seconds: 9);
      return url == source ? _Response(302, target) : _Response(200);
    });
    final result = await HttpUrlExpander(
      sessionFactory: () => session,
      stopwatchFactory: () => clock,
    ).expandUrl(source);
    expect(result.status, UrlExpansionStatus.resolved);
    expect(session.requests.map((r) => r.timeout), [
      const Duration(seconds: 4),
      const Duration(seconds: 3),
      const Duration(seconds: 3),
    ]);
  });

  test(
    'does not send another request when monotonic budget is exhausted',
    () async {
      final clock = _Clock();
      final session = _Session((_, _) async {
        clock.elapsed = HttpUrlExpander.expansionBudget;
        return _Response(302, target);
      });
      final result = await HttpUrlExpander(
        sessionFactory: () => session,
        stopwatchFactory: () => clock,
      ).expandUrl(source);
      expect(result.status, UrlExpansionStatus.timeout);
      expect(result.announcedDestination, target);
      expect(result.verifiedDestination, isNull);
      expect(session.requests, hasLength(1));
      expect(session.closed, isTrue);
    },
  );

  for (final lateError in [false, true]) {
    testWidgets(
      'global 12s deadline closes session and ignores late ${lateError ? 'error' : 'response'}',
      (tester) async {
        final pending = Completer<_Response>();
        final session = _Session(
          (_, url) async =>
              url == source ? _Response(302, target) : pending.future,
        );
        var completions = 0;
        final future = HttpUrlExpander(sessionFactory: () => session)
            .expandUrl(source)
            .then((r) {
              completions++;
              return r;
            });
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 11999));
        expect(completions, 0);
        await tester.pump(const Duration(milliseconds: 1));
        final result = await future;
        expect(result.status, UrlExpansionStatus.timeout);
        expect(result.announcedDestination, target);
        expect(result.verifiedDestination, isNull);
        expect(result.lastHttpStatus, 302);
        expect(session.closed, isTrue);
        final late = _Response(302, '$target/late');
        if (lateError) {
          pending.completeError(StateError('late'));
        } else {
          pending.complete(late);
        }
        await tester.pump();
        expect(session.requests, hasLength(2));
        expect(completions, 1);
        if (!lateError) expect(late.closed, isTrue);
        expect(result.lastHttpStatus, 302);
        expect(result.announcedDestination, target);
      },
    );
  }

  for (final location in [
    'https://%64estination.scamlens.net/path',
    '//destination.scamlens.net:0443/path',
  ]) {
    test(
      'does not erase ambiguous authority before validation: $location',
      () async {
        final session = _Session((_, _) async => _Response(302, location));
        final result = await HttpUrlExpander(sessionFactory: () => session)
            .expandUrl(source);
        expect(result.status, UrlExpansionStatus.blocked);
        expect(result.verifiedDestination, isNull);
        expect(session.requests, hasLength(1));
      },
    );
  }

  for (final status in [404, 500]) {
    test('terminal GET $status cannot confirm a successful HEAD', () async {
      final session = _Session(
        (method, url) async => url == source
            ? _Response(302, target)
            : _Response(method == 'HEAD' ? 200 : status),
      );
      final result = await HttpUrlExpander(sessionFactory: () => session)
          .expandUrl(source);
      expect(result.status, UrlExpansionStatus.failed);
      expect(result.lastHttpStatus, status);
      expect(result.verifiedDestination, isNull);
      expect(result.announcedDestination, target);
    });
  }

  test('shared processing uses secure session and preserves original request query', () async {
    const raw = ' https://bit.ly/a?utm_source=x&id=1&id=2&z=%2F#part ';
    final session = _Session(
      (_, url) async => url.startsWith(source)
          ? _Response(302, '$target?b=2&b=1')
          : _Response(200),
    );
    final process = ProcessUrlUseCase(
      normalizer: UrlNormalizer(),
      expander: HttpUrlExpander(sessionFactory: () => session),
    );
    final result = await process(raw);
    expect(result.contentRaw, raw);
    expect(result.normalizedUrl, UrlNormalizer().normalizeUrl(raw));
    expect(
      session.requests.first.url,
      'https://bit.ly/a?utm_source=x&id=1&id=2&z=%2F',
    );
    expect(result.expansion!.status, UrlExpansionStatus.resolved);
    expect(result.expansion!.verifiedDestination, '$target?b=2&b=1');
    expect(result.wasShortened, isTrue);
  });

  test('each expansion creates and closes an independent session', () async {
    final sessions = <_Session>[];
    final expander = HttpUrlExpander(
      sessionFactory: () {
        final session = _Session((_, _) async => _Response(200));
        sessions.add(session);
        return session;
      },
    );
    await Future.wait([expander.expandUrl(source), expander.expandUrl(source)]);
    expect(sessions, hasLength(2));
    expect(sessions.every((s) => s.closed), isTrue);
  });
}
