import 'package:flutter_test/flutter_test.dart';
import 'package:scamlens/shared/brand_impersonation/domain/services/registrable_domain_extractor.dart';

void main() {
  final extractor = RegistrableDomainExtractor();

  group('RegistrableDomainExtractor', () {
    test('extracts root domain stripping subdomains, paths, queries and fragments', () {
      final result = extractor.extract(
        'https://sucursalpersonas.bancolombia.com:443/login?user=1#auth',
      );

      expect(result, isNotNull);
      expect(result!.fullHost, 'sucursalpersonas.bancolombia.com');
      expect(result.rootDomain, 'bancolombia.com');
      expect(result.brandLabel, 'bancolombia');
      expect(result.publicSuffix, 'com');
    });

    test('supports Colombian and regional compound public suffixes', () {
      final ml = extractor.extract('https://pagos.mercadolibre.com.co/checkout');
      expect(ml, isNotNull);
      expect(ml!.rootDomain, 'mercadolibre.com.co');
      expect(ml.brandLabel, 'mercadolibre');
      expect(ml.publicSuffix, 'com.co');

      final dian = extractor.extract('https://muisca.dian.gov.co/WebArquitectura');
      expect(dian, isNotNull);
      expect(dian!.rootDomain, 'dian.gov.co');
      expect(dian.brandLabel, 'dian');
      expect(dian.publicSuffix, 'gov.co');

      final edu = extractor.extract('portal.icesi.edu.co');
      expect(edu, isNotNull);
      expect(edu!.rootDomain, 'icesi.edu.co');
      expect(edu.brandLabel, 'icesi');
      expect(edu.publicSuffix, 'edu.co');
    });

    test('returns null for bare compound suffixes, IP literals and invalid hosts', () {
      expect(extractor.extract(''), isNull);
      expect(extractor.extract('   '), isNull);
      expect(extractor.extract('https://com.co/path'), isNull);
      expect(extractor.extract('https://192.168.1.1/login'), isNull);
      expect(extractor.extract('https://8.8.8.8/'), isNull);
      expect(extractor.extract('https://[2001:4860:4860::8888]/'), isNull);
      expect(extractor.extract('localhost'), isNull);
    });
  });
}
