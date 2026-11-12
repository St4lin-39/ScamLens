import 'package:flutter_test/flutter_test.dart';
import 'package:scamlens/features/smishing/domain/entities/sms_analysis_result.dart';
import 'package:scamlens/shared/url_processing/domain/entities/url_processing_result.dart';

void main() {
  const url = UrlProcessingResult(
    contentRaw: 'www.example.com',
    normalizedUrl: 'https://www.example.com/',
    isUrl: true,
    wasShortened: false,
  );

  test('copies source list and preserves repeated immutable results', () {
    final source = [url, url];
    final result = SmsAnalysisResult(originalText: ' original ', urls: source);
    source.clear();
    expect(result.originalText, ' original ');
    expect(result.urls, [url, url]);
    expect(() => result.urls.add(url), throwsUnsupportedError);
    expect(() => result.urls[0] = url, throwsUnsupportedError);
    expect(() => result.urls.clear(), throwsUnsupportedError);
  });
}
