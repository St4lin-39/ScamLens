import 'package:flutter_test/flutter_test.dart';
import 'package:scamlens/shared/ioc_verification/domain/services/ioc_candidate_extractor.dart';

void main() {
  final extractor = IocCandidateExtractor();

  group('IocCandidateExtractor', () {
    test('extracts hierarchical domain ladder without bare public suffixes', () {
      final set = extractor.extract(
        normalizedUrl: 'https://login.pagos.secure-verify-account.xyz/auth',
      );

      expect(
        set.domains,
        containsAll(<String>[
          'login.pagos.secure-verify-account.xyz',
          'pagos.secure-verify-account.xyz',
          'secure-verify-account.xyz',
        ]),
      );
      expect(set.domains, isNot(contains('xyz')));
    });

    test('canonicalizes URLs stripping victim tokens, fragments, default ports and cross-scheme paths', () {
      final set = extractor.extract(
        normalizedUrl:
            'HTTPS://PROMO-BONO-REGALO.ONLINE:443/reclamar/?victim=300123&utm_source=sms#top',
      );

      expect(
        set.urls,
        contains('https://promo-bono-regalo.online/reclamar?victim=300123'),
      );
      expect(
        set.urls,
        contains('https://promo-bono-regalo.online/reclamar'),
      );
      expect(
        set.urls,
        contains('http://promo-bono-regalo.online/reclamar'),
      );
    });

    test('extracts IPv4 and IPv6 literals cleanly without ports or brackets', () {
      final ipv4 = extractor.extract(
        normalizedUrl: 'http://198.51.100.42:8080/payload.apk',
      );
      expect(ipv4.ips, {'198.51.100.42'});
      expect(ipv4.domains, isEmpty);

      final ipv6 = extractor.extract(
        normalizedUrl: 'http://[2001:db8::1]:8080/login',
      );
      expect(ipv6.ips, {'2001:db8::1'});
      expect(ipv6.domains, isEmpty);
    });

    test('excludes shorteners, shared hosting, and official brands from DOMAIN candidates while keeping URL candidates', () {
      final shortener = extractor.extract(
        normalizedUrl: 'https://bit.ly/3xYqz',
        verifiedDestination: 'https://sites.google.com/view/fake-prize',
        protectedDomains: const ['bancolombia.com', 'google.com'],
      );

      expect(shortener.domains, isEmpty);
      expect(shortener.urls, contains('https://bit.ly/3xYqz'));
      expect(
        shortener.urls,
        contains('https://sites.google.com/view/fake-prize'),
      );
      expect(
        shortener.remoteLookupUrls,
        containsAll(<String>[
          'https://bit.ly/3xYqz',
          'https://sites.google.com/view/fake-prize',
        ]),
      );
    });
  });
}
