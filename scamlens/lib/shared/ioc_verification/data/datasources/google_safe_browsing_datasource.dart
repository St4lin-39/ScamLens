import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/entities/indicator_of_compromise.dart';

class GoogleSafeBrowsingDatasource {
  static const String sourceName = 'GOOGLE_SAFE_BROWSING';

  final String apiKey;
  final http.Client httpClient;
  final Duration timeout;
  final DateTime Function() clock;

  GoogleSafeBrowsingDatasource({
    required this.apiKey,
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 4),
    DateTime Function()? clock,
  }) : httpClient = httpClient ?? http.Client(),
       clock = clock ?? DateTime.now;

  bool get isConfigured => apiKey.trim().isNotEmpty;

  Future<IndicatorOfCompromise?> lookupUrls(Iterable<String> urls) async {
    if (!isConfigured) return null;

    final entries = urls
        .map((u) => u.trim())
        .where((u) => u.isNotEmpty)
        .toSet()
        .take(50)
        .map((u) => <String, String>{'url': u})
        .toList(growable: false);

    if (entries.isEmpty) return null;

    final endpoint = Uri.https(
      'safebrowsing.googleapis.com',
      '/v4/threatMatches:find',
      <String, String>{'key': apiKey.trim()},
    );

    final payload = jsonEncode(<String, Object>{
      'client': <String, String>{
        'clientId': 'scamlens',
        'clientVersion': '1.1.0',
      },
      'threatInfo': <String, Object>{
        'threatTypes': const <String>[
          'MALWARE',
          'SOCIAL_ENGINEERING',
          'UNWANTED_SOFTWARE',
          'POTENTIALLY_HARMFUL_APPLICATION',
        ],
        'platformTypes': const <String>['ANY_PLATFORM'],
        'threatEntryTypes': const <String>['URL'],
        'threatEntries': entries,
      },
    });

    final response = await httpClient
        .post(
          endpoint,
          headers: const <String, String>{'Content-Type': 'application/json'},
          body: payload,
        )
        .timeout(timeout);

    if (response.statusCode != 200) {
      throw StateError(
        'Safe Browsing lookup failed with HTTP ${response.statusCode}',
      );
    }

    if (response.body.trim().isEmpty) return null;

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) return null;

    final matches = decoded['matches'];
    if (matches is! List || matches.isEmpty) return null;

    final first = matches.first;
    if (first is! Map<String, dynamic>) return null;

    final threatMap = first['threat'];
    final matchedUrl = threatMap is Map<String, dynamic>
        ? (threatMap['url'] as String?)?.trim()
        : null;
    final threatType =
        (first['threatType'] as String?)?.trim() ?? 'MALICIOUS_URL';
    final effectiveUrl = (matchedUrl != null && matchedUrl.isNotEmpty)
        ? matchedUrl
        : entries.first['url']!;

    return IndicatorOfCompromise(
      id: 'gsb-${effectiveUrl.hashCode.toUnsigned(32).toRadixString(16)}',
      type: IocType.url,
      value: effectiveUrl,
      attackType: _formatThreatType(threatType),
      detectionSource: sourceName,
      active: true,
      createdIn: clock().toUtc(),
    );
  }

  String _formatThreatType(String raw) => switch (raw) {
    'SOCIAL_ENGINEERING' => 'PHISHING (SOCIAL_ENGINEERING)',
    'POTENTIALLY_HARMFUL_APPLICATION' => 'HARMFUL_APP',
    _ => raw,
  };
}
