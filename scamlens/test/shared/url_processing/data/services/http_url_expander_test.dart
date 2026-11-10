import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:scamlens/core/config/url_config.dart';
import 'package:scamlens/shared/url_processing/data/services/http_url_expander.dart';
import 'package:scamlens/shared/url_processing/domain/services/url_normalizer.dart';

void main() {
  group('HTTP expansion with input/output normalization', () {
    for (final status in [301, 302, 303, 307, 308]) {
      test('follows $status with HEAD and manual redirects', () async {
        final requests = <http.Request>[];
        final client = MockClient((request) async {
          requests.add(request);
          return requests.length == 1
              ? http.Response(
                  '',
                  status,
                  headers: {
                    'location':
                        'https://destination.example/path?utm_source=x#end',
                  },
                )
              : http.Response('', 200);
        });
        addTearDown(client.close);
        final result = UrlNormalizer().normalizeUrl(
          await HttpUrlExpander(client)
              .expandUrl(UrlNormalizer().normalizeUrl('https://bit.ly/abc')),
        );
        expect(result, 'https://destination.example/path#end');
        expect(requests.map((r) => r.url.toString()), [
          'https://bit.ly/abc',
          'https://destination.example/path?utm_source=x#end',
        ]);
        expect(requests.every((r) => r.method == 'HEAD'), isTrue);
        expect(requests.every((r) => !r.followRedirects), isTrue);
      });
    }

    test('resolves relative Location against current URL', () async {
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
        return calls == 1
            ? http.Response('', 302, headers: {'location': '../target?id=1'})
            : http.Response('', 200);
      });
      addTearDown(client.close);
      expect(
        UrlNormalizer().normalizeUrl(
          await HttpUrlExpander(client).expandUrl(
            UrlNormalizer().normalizeUrl('https://bit.ly/folder/code'),
          ),
        ),
        'https://bit.ly/target?id=1',
      );
      expect(calls, 2);
    });

    test(
      'stops after five requests even for an endless redirect chain',
      () async {
        var calls = 0;
        final client = MockClient((_) async {
          calls++;
          return http.Response('', 302, headers: {'location': '/step$calls'});
        });
        addTearDown(client.close);
        expect(UrlConfig.maxRedirects, 5);
        expect(
          UrlNormalizer().normalizeUrl(
            await HttpUrlExpander(client)
                .expandUrl(UrlNormalizer().normalizeUrl('https://bit.ly/a')),
          ),
          'https://bit.ly/step5',
        );
        expect(calls, 5);
      },
    );

    for (final status in [200, 300, 304, 400, 404, 405, 500]) {
      test('$status stops without throwing or attempting GET', () async {
        var calls = 0;
        final client = MockClient((request) async {
          calls++;
          expect(request.method, 'HEAD');
          return http.Response('', status, headers: {'location': '/ignored'});
        });
        addTearDown(client.close);
        expect(
          UrlNormalizer().normalizeUrl(
            await HttpUrlExpander(client).expandUrl(
              UrlNormalizer().normalizeUrl('https://bit.ly/a?utm_source=x'),
            ),
          ),
          'https://bit.ly/a',
        );
        expect(calls, 1);
      });
    }

    for (final location in [null, '']) {
      test('redirect with Location=$location returns current URL', () async {
        var calls = 0;
        final client = MockClient((_) async {
          calls++;
          return http.Response(
            '',
            302,
            headers: location == null ? {} : {'location': location},
          );
        });
        addTearDown(client.close);
        expect(
          UrlNormalizer().normalizeUrl(
            await HttpUrlExpander(client)
                .expandUrl(UrlNormalizer().normalizeUrl('https://bit.ly/a')),
          ),
          'https://bit.ly/a',
        );
        expect(calls, 1);
      });
    }

    for (final failAfterRedirect in [false, true]) {
      test(
        'transport failure preserves last URL (redirect=$failAfterRedirect)',
        () async {
          var calls = 0;
          final client = MockClient((_) async {
            calls++;
            if (failAfterRedirect && calls == 1) {
              return http.Response('', 302, headers: {'location': '/reached'});
            }
            throw http.ClientException('Simulated offline');
          });
          addTearDown(client.close);
          expect(
            UrlNormalizer().normalizeUrl(
              await HttpUrlExpander(client)
                  .expandUrl(UrlNormalizer().normalizeUrl('https://bit.ly/a')),
            ),
            failAfterRedirect ? 'https://bit.ly/reached' : 'https://bit.ly/a',
          );
          expect(calls, failAfterRedirect ? 2 : 1);
        },
      );
    }

    test('four-second request timeout returns current URL', () async {
      final pending = Completer<http.Response>();
      final client = MockClient((_) => pending.future);
      addTearDown(client.close);
      expect(UrlConfig.requestTimeout, const Duration(seconds: 4));
      expect(
        UrlNormalizer().normalizeUrl(
          await HttpUrlExpander(client)
              .expandUrl(UrlNormalizer().normalizeUrl('https://bit.ly/a')),
        ),
        'https://bit.ly/a',
      );
      pending.complete(http.Response('', 200));
    });
  });
}
