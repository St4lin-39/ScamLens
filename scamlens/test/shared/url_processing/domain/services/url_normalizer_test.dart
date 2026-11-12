import 'package:flutter_test/flutter_test.dart';
import 'package:scamlens/shared/url_processing/domain/services/url_normalizer.dart';

void main() {
  group('normalizeUrl: current serialization', () {
    late UrlNormalizer normalizer;
    setUp(() {
      normalizer = UrlNormalizer();
    });

    final cases = <String, String>{
      'http://example.com': 'http://example.com/',
      'https://example.com': 'https://example.com/',
      '  www.Example.com  ': 'https://www.example.com/',
      'https://EXAMPLE.COM/SomePath': 'https://example.com/SomePath',
      // HTTP scheme recognition is case insensitive.
      'HTTPS://EXAMPLE.COM': 'https://example.com/',
      'http://example.com:80': 'http://example.com/',
      'https://example.com:443': 'https://example.com/',
      'https://example.com:8443': 'https://example.com:8443/',
      'https://example.com/path#Section': 'https://example.com/path#Section',
      'https://example.com/?UTM_SOURCE=x&fbclid=y&id=42':
          'https://example.com/?id=42',
      'https://example.com/?utm_source=x': 'https://example.com/',
      // queryParameters collapses repeated values rather than preserving them.
      'https://example.com/?id=1&id=2': 'https://example.com/?id=2',
      '   ': '',
    };
    for (final entry in cases.entries) {
      test('${entry.key} -> ${entry.value}', () {
        expect(normalizer.normalizeUrl(entry.key), entry.value);
      });
    }
  });

  group('isShortenedUrl', () {
    final cases = <String, bool>{
      'https://bit.ly/abc': true,
      'https://sub.bit.ly/abc': true,
      'https://BIT.LY/abc': true,
      'https://bit.ly.example.com/abc': false,
      'https://notbit.ly/abc': false,
      'https://example.com/abc': false,
    };
    for (final entry in cases.entries) {
      test(entry.key, () {
        expect(UrlNormalizer().isShortenedUrl(entry.key), entry.value);
      });
    }
  });
}
