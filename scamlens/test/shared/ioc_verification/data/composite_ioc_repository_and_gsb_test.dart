import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:scamlens/shared/ioc_verification/data/datasources/google_safe_browsing_datasource.dart';
import 'package:scamlens/shared/ioc_verification/data/datasources/supabase_ioc_datasource.dart';
import 'package:scamlens/shared/ioc_verification/data/models/indicator_of_compromise_model.dart';
import 'package:scamlens/shared/ioc_verification/data/repositories/composite_ioc_repository.dart';
import 'package:scamlens/shared/ioc_verification/domain/entities/indicator_of_compromise.dart';
import 'package:scamlens/shared/ioc_verification/domain/entities/ioc_check_result.dart';

class _FakeSupabaseIocDatasource implements SupabaseIocDatasource {
  int calls = 0;
  Future<List<IndicatorOfCompromiseModel>> Function(List<String>) onFind =
      (_) async => const [];

  @override
  Never get client => throw UnimplementedError();

  @override
  Future<List<IndicatorOfCompromiseModel>> findActiveMatches(
    List<String> candidateValues,
  ) {
    calls++;
    return onFind(candidateValues);
  }
}

void main() {
  group('GoogleSafeBrowsingDatasource & CompositeIocRepository', () {
    test('GoogleSafeBrowsingDatasource parses threatMatches:find JSON match and empty safe response', () async {
      late Map<String, dynamic> capturedBody;
      final client = MockClient((request) async {
        expect(request.url.host, 'safebrowsing.googleapis.com');
        expect(request.url.path, '/v4/threatMatches:find');
        expect(request.url.queryParameters['key'], 'test-key');
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;

        final entries =
            (capturedBody['threatInfo']
                    as Map<String, dynamic>)['threatEntries']
                as List<dynamic>;
        final hasMalicious = entries.any(
          (e) =>
              (e as Map<String, dynamic>)['url'] ==
              'https://testsafebrowsing.appspot.com/s/phishing.html',
        );

        if (!hasMalicious) {
          return http.Response('{}', 200);
        }

        return http.Response(
          jsonEncode({
            'matches': [
              {
                'threatType': 'SOCIAL_ENGINEERING',
                'platformType': 'ANY_PLATFORM',
                'threat': {
                  'url': 'https://testsafebrowsing.appspot.com/s/phishing.html',
                },
                'cacheDuration': '300s',
                'threatEntryType': 'URL',
              },
            ],
          }),
          200,
        );
      });

      final gsb = GoogleSafeBrowsingDatasource(
        apiKey: 'test-key',
        httpClient: client,
      );

      final safe = await gsb.lookupUrls(['https://bancolombia.com/']);
      expect(safe, isNull);

      final hit = await gsb.lookupUrls([
        'https://testsafebrowsing.appspot.com/s/phishing.html',
      ]);
      expect(hit, isNotNull);
      expect(hit!.detectionSource, 'GOOGLE_SAFE_BROWSING');
      expect(hit.attackType, 'PHISHING (SOCIAL_ENGINEERING)');
      expect(hit.type, IocType.url);
    });

    test('CompositeIocRepository short-circuits on Supabase hit without calling Google Safe Browsing', () async {
      final supabase = _FakeSupabaseIocDatasource()
        ..onFind = (_) async => [
          IndicatorOfCompromiseModel.fromJson({
            'id': '99999999-9999-4999-8999-999999999999',
            'type': 'DOMAIN',
            'value': 'secure-verify-account.xyz',
            'attack_type': 'PHISHING',
            'detection_source': 'OPENPHISH',
            'active': true,
            'created_in': '2026-11-26T00:00:00Z',
          }),
        ];

      var gsbCalls = 0;
      final gsb = GoogleSafeBrowsingDatasource(
        apiKey: 'test-key',
        httpClient: MockClient((_) async {
          gsbCalls++;
          return http.Response('{}', 200);
        }),
      );

      final repo = CompositeIocRepository(
        supabaseDatasource: supabase,
        safeBrowsingDatasource: gsb,
      );

      final candidates = IocCandidateSet(
        domains: {'secure-verify-account.xyz'},
        urls: {'https://secure-verify-account.xyz/login'},
        remoteLookupUrls: {'https://secure-verify-account.xyz/login'},
      );

      final first = await repo.checkCandidates(candidates);
      final secondCached = await repo.checkCandidates(candidates);

      expect(first.isConfirmedThreat, isTrue);
      expect(first.matchedIoc?.detectionSource, 'OPENPHISH');
      expect(secondCached.isConfirmedThreat, isTrue);
      expect(supabase.calls, 1);
      expect(gsbCalls, 0);
    });

    test('CompositeIocRepository falls back to Google Safe Browsing when Supabase is clean or offline', () async {
      final supabase = _FakeSupabaseIocDatasource()
        ..onFind = (_) async => throw Exception('Supabase offline');

      final gsb = GoogleSafeBrowsingDatasource(
        apiKey: 'test-key',
        httpClient: MockClient((_) async {
          return http.Response(
            jsonEncode({
              'matches': [
                {
                  'threatType': 'MALWARE',
                  'threat': {'url': 'https://evil-payload.example/app.apk'},
                },
              ],
            }),
            200,
          );
        }),
      );

      final repo = CompositeIocRepository(
        supabaseDatasource: supabase,
        safeBrowsingDatasource: gsb,
      );

      final result = await repo.checkCandidates(
        IocCandidateSet(
          domains: {'evil-payload.example'},
          urls: {'https://evil-payload.example/app.apk'},
          remoteLookupUrls: {'https://evil-payload.example/app.apk'},
        ),
      );

      expect(result.isConfirmedThreat, isTrue);
      expect(result.sourceAvailability, IocSourceAvailability.partial);
      expect(result.matchedIoc?.attackType, 'MALWARE');
      expect(result.matchedIoc?.detectionSource, 'GOOGLE_SAFE_BROWSING');
    });
  });
}
