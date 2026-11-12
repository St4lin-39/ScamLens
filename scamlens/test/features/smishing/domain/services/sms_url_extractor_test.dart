import 'package:flutter_test/flutter_test.dart';
import 'package:scamlens/features/smishing/domain/services/sms_url_extractor.dart';

void main() {
  final extractor = SmsUrlExtractor();
  final cases = <String, List<String>>{
    '': [],
    ' \n\t ': [],
    'Un mensaje sin enlaces': [],
    'Visita https://example.com': ['https://example.com'],
    'http://a.example https://b.example www.c.example': [
      'http://a.example',
      'https://b.example',
      'www.c.example',
    ],
    'https://a.example https://b.example https://a.example': [
      'https://a.example',
      'https://b.example',
      'https://a.example',
    ],
    'https://example.com/a/b?q=uno&x=2#seccion': [
      'https://example.com/a/b?q=uno&x=2#seccion',
    ],
    '(https://a.example/a), [www.b.example/b]. ¡https://c.example/c!': [
      'https://a.example/a',
      'www.b.example/b',
      'https://c.example/c',
    ],
    'https://a.example\nwww.b.example\r\nhttp://c.example': [
      'https://a.example',
      'www.b.example',
      'http://c.example',
    ],
    'example.com ftp://example.com user@www.example.com abcwww.example.com': [
      'example.com',
      'abcwww.example.com',
    ],
    'ñexample.com éhttps://example.com palabra_https://example.com': [],
    'HtTpS://Example.com/a': ['HtTpS://Example.com/a'],
    'sms.bellapiel.com.co/2BP5ZRvI sms.bellapiel.com.co/Tbx5JpyP': [
      'sms.bellapiel.com.co/2BP5ZRvI',
      'sms.bellapiel.com.co/Tbx5JpyP',
    ],
    'http://a.com https://b.com www.c.com d.com/ruta bit.ly/abc123 d.com/ruta':
        [
          'http://a.com',
          'https://b.com',
          'www.c.com',
          'd.com/ruta',
          'bit.ly/abc123',
          'd.com/ruta',
        ],
    'subdominio.banco.com.co/acceso portal.gov.co/a campus.edu.co/b example.unlistedtld/a':
        [
          'subdominio.banco.com.co/acceso',
          'portal.gov.co/a',
          'campus.edu.co/b',
          'example.unlistedtld/a',
        ],
    '"example.com:8443/a_(b)?items=a,b&x=2#part", (example.com/a_(b)).': [
      'example.com:8443/a_(b)?items=a,b&x=2#part',
      'example.com/a_(b)',
    ],
    '192.168.1.1/a http://127.0.0.1 https://255.255.255.255/a': [
      '192.168.1.1/a',
      'http://127.0.0.1',
      'https://255.255.255.255/a',
    ],
    '192.168.1.1 256.1.1.1/a 1.2.3/a 01.2.3.4/a https://999.1.1.1/a': [],
    '11:11 12/11 12.11.2026 30.5 1.2.3 v1.2.3 correo+tag@example.com user@www.example.com':
        [],
    'banco[.]ejemplo[.]com/login hxxps://example.com example . com': [],
    'prefix_https://example.com -bad.example.com https://bad.example:0/a example.com:65536/a':
        [],
    'https:// https://[invalid www. https://-bad.example https://bad_.example':
        [],
    '“https://a.example” <www.b.example>': [
      'https://a.example',
      'www.b.example',
    ],
    'https://example.com/wiki/Topic_(detail)).': [
      'https://example.com/wiki/Topic_(detail)',
    ],
    'https://example.com/?items=a,b&next=%2Fpath#part': [
      'https://example.com/?items=a,b&next=%2Fpath#part',
    ],
    'HTTP://EXAMPLE.COM HTTPS://EXAMPLE.COM WWW.EXAMPLE.COM': [
      'HTTP://EXAMPLE.COM',
      'HTTPS://EXAMPLE.COM',
      'WWW.EXAMPLE.COM',
    ],
    'https://example.com:443/a https://example.com:99999/a': [
      'https://example.com:443/a',
    ],
    'https://[2001:db8::1]/path https://127.0.0.1/a': [
      'https://[2001:db8::1]/path',
      'https://127.0.0.1/a',
    ],
  };

  var index = 0;
  for (final entry in cases.entries) {
    test('extracts supported URLs without changing them, case ${index++}', () {
      expect(extractor.extract(entry.key), entry.value);
    });
  }

  test('extracted list is immutable', () {
    final urls = extractor.extract('https://example.com');
    expect(() => urls.add('https://other.example'), throwsUnsupportedError);
  });
}
