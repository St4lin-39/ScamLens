import 'package:flutter_test/flutter_test.dart';
import 'package:scamlens/shared/url_processing/data/transport/public_address_policy.dart';

void main() {
  const policy = PublicAddressPolicy();

  group('public literal addresses', () {
    for (final address in [
      '1.1.1.1',
      '8.8.8.8',
      '93.184.216.34',
      '192.0.0.9',
      '192.0.0.10',
      '192.31.196.1',
      '192.52.193.1',
      '192.175.48.1',
      '2001:4860:4860::8888',
      '2606:4700:4700::1111',
      '2800:3f0:4001::1',
      '2a00:1450::1',
      '2a10::1',
      '2410::1',
      '2630::1',
      '2c00::1',
      '2001:1::1',
      '2001:1::2',
      '2001:1::3',
      '2001:3::1',
      '2001:4:112::1',
      '2620:4f:8000::1',
      '2606:4700:0:0:0:0:0:1111',
      '2001:4860::ABCD',
    ]) {
      test(address, () {
        final result = policy.validateAddress(address);
        expect(result.isAllowed, isTrue);
        expect(result.reason, isNull);
      });
    }
  });

  group('special-use IPv4 including prefix endpoints', () {
    for (final address in [
      '0.0.0.0',
      '0.255.255.255',
      '10.0.0.0',
      '10.255.255.255',
      '100.64.0.0',
      '100.127.255.255',
      '127.0.0.0',
      '127.255.255.255',
      '169.254.0.0',
      '169.254.255.255',
      '172.16.0.0',
      '172.31.255.255',
      '192.0.0.0',
      '192.0.0.8',
      '192.0.0.11',
      '192.0.0.170',
      '192.0.0.171',
      '192.0.0.255',
      '192.0.2.0',
      '192.0.2.255',
      '192.88.99.0',
      '192.88.99.2',
      '192.88.99.255',
      '192.168.0.0',
      '192.168.255.255',
      '198.18.0.0',
      '198.19.255.255',
      '198.51.100.0',
      '198.51.100.255',
      '203.0.113.0',
      '203.0.113.255',
      '224.0.0.0',
      '239.255.255.255',
      '240.0.0.0',
      '255.255.255.255',
    ]) {
      test(address, () {
        expect(
          policy.validateAddress(address).reason,
          DestinationBlockReason.specialUseAddress,
        );
      });
    }
  });

  group('public neighbors are not blocked by overly broad prefixes', () {
    for (final address in [
      '1.0.0.0',
      '9.255.255.255',
      '11.0.0.0',
      '100.63.255.255',
      '100.128.0.0',
      '126.255.255.255',
      '128.0.0.0',
      '169.253.255.255',
      '169.255.0.0',
      '172.15.255.255',
      '172.32.0.0',
      '191.255.255.255',
      '192.0.1.0',
      '192.0.1.255',
      '192.0.3.0',
      '192.88.98.255',
      '192.88.100.0',
      '192.167.255.255',
      '192.169.0.0',
      '198.17.255.255',
      '198.20.0.0',
      '198.51.99.255',
      '198.51.101.0',
      '203.0.112.255',
      '203.0.114.0',
      '223.255.255.255',
      '2001:200::',
      '2001:db7:ffff:ffff:ffff:ffff:ffff:ffff',
      '2001:db9::',
      '2001:3:ffff:ffff:ffff:ffff:ffff:ffff',
      '2001:4:112:ffff:ffff:ffff:ffff:ffff',
      '2003:3fff:ffff:ffff:ffff:ffff:ffff:ffff',
      '241f:ffff:ffff:ffff:ffff:ffff:ffff:ffff',
      '2a1f:ffff:ffff:ffff:ffff:ffff:ffff:ffff',
      '2c0f:ffff:ffff:ffff:ffff:ffff:ffff:ffff',
    ]) {
      test(
        address,
        () => expect(policy.validateAddress(address).isAllowed, isTrue),
      );
    }
  });

  group('IPv6 prohibited mechanisms and special use', () {
    for (final address in [
      '::',
      '::1',
      '::8.8.8.8',
      '::ffff:8.8.8.8',
      '::ffff:127.0.0.1',
      '::ffff:808:808',
      '64:ff9b::808:808',
      '64:ff9b:1::1',
      '100::',
      '100::ffff:ffff:ffff:ffff',
      '100:0:0:1::1',
      '2001::1',
      '2001:0:ffff:ffff:ffff:ffff:ffff:ffff',
      '2001:1::',
      '2001:1::4',
      '2001:2::1',
      '2001:4:111::1',
      '2001:4:113::1',
      '2001:10::1',
      '2001:20::1',
      '2001:30::1',
      '2001:1ff:ffff:ffff:ffff:ffff:ffff:ffff',
      '2001:db8::',
      '2001:db8:ffff:ffff:ffff:ffff:ffff:ffff',
      '2002::',
      '2002:ffff:ffff:ffff:ffff:ffff:ffff:ffff',
      '3fff::',
      '3fff:fff:ffff:ffff:ffff:ffff:ffff:ffff',
      '5f00::1',
      'fc00::',
      'fdff:ffff:ffff:ffff:ffff:ffff:ffff:ffff',
      'fe80::',
      'febf:ffff:ffff:ffff:ffff:ffff:ffff:ffff',
      'ff00::',
      'ffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff',
    ]) {
      test(
        address,
        () => expect(
          policy.validateAddress(address).reason,
          DestinationBlockReason.specialUseAddress,
        ),
      );
    }
  });

  group('IPv6 unallocated and uncertain addresses fail closed', () {
    for (final address in [
      '2000:ffff::1',
      '2001:1000::1',
      '2001:6000::1',
      '2001:c000::1',
      '2003:4000::',
      '2420::',
      '2610:200::',
      '2620:200::',
      '2c10::',
      '2d00::1',
      '3000::1',
      '3ffe::1',
      '3fff:1000::',
      '4000::1',
      'fbff:ffff::',
      'fe00::',
      'fec0::',
    ]) {
      test(
        address,
        () => expect(
          policy.validateAddress(address).reason,
          DestinationBlockReason.unallocatedAddress,
        ),
      );
    }
  });

  group('invalid or ambiguous address spellings', () {
    for (final address in [
      '',
      '8.8.8',
      '8.8.8.256',
      '008.8.8.8',
      '0x08080808',
      '134744072',
      '127.1',
      '0177.0.0.1',
      '1.2.3.-1',
      '8.8.8.8 ',
      ' 8.8.8.8',
      '[2606:4700::1]',
      '2001:::1',
      '2001::1::2',
      'gggg::1',
      '1:2:3:4:5:6:7',
      '1:2:3:4:5:6:7:8:9',
      '::ffff:008.8.8.8',
      'dns.google',
      'https://8.8.8.8',
      '8.8.8.8:80',
    ]) {
      test(
        address,
        () => expect(
          policy.validateAddress(address).reason,
          DestinationBlockReason.invalidAddress,
        ),
      );
    }
    for (final address in [
      'fe80::1%eth0',
      'fe80::1%25eth0',
      '2606:4700::1%1',
    ]) {
      test(
        'scope $address',
        () => expect(
          policy.validateAddress(address).reason,
          DestinationBlockReason.scopedAddress,
        ),
      );
    }
  });

  group('URI syntax approval is independent of DNS', () {
    for (final url in [
      'https://google.com',
      'http://google.com/path?q=1#part',
      'HTTPS://GOOGLE.COM',
      'https://google.com:443/',
      'http://google.com:80',
      'https://google.com:80',
      'http://google.com:443',
      'https://8.8.8.8',
      'https://[2606:4700:4700::1111]:443/a',
      'https://xn--bcher-kva.de',
      'https://bit.ly.ejemplo.com',
      'https://notlocalhost.com',
      'https://public.local.ejemplo.com',
      'https://google.com/path%20name?q=hello%20world',
    ]) {
      test(url, () => expect(policy.validateUri(url).isAllowed, isTrue));
    }
    for (final url in [
      '',
      'https://',
      'https:///path',
      'https:google.com',
      '//google.com',
      'google.com',
      'ftp://google.com',
      'file:///etc/hosts',
      'javascript:alert(1)',
      'https://user:pass@google.com',
      'https://@google.com',
      'https://localhost',
      'https://LOCALHOST',
      'https://a.localhost',
      'https://printer.local',
      'https://a.internal',
      'https://a.lan',
      'https://a.localdomain',
      'https://a.intranet',
      'https://a.corp',
      'https://a.home.arpa',
      'https://a.onion',
      'https://a.invalid',
      'https://a.test',
      'https://example.com',
      'https://a.example.net',
      'https://metadata',
      'https://printer',
      'https://google.com:0',
      'https://google.com:8080',
      'https://google.com:65536',
      'https://google.com:',
      'https://google.com:0443',
      'https://google.com:+443',
      'https://google.com.',
      'https://google..com',
      'https://-google.com',
      'https://google-.com',
      'https://under_score.com',
      'https://bücher.de',
      'https://%67oogle.com',
      'https://google.com\\@127.0.0.1',
      ' https://google.com',
      'https://google.com/with space',
      'https://google.com/\n',
      'https://google.com/\u0000',
      'https://127.1',
      'https://2130706433',
      'https://0177.0.0.1',
      'https://0x7f000001',
      'https://0x7f.0.0.1',
      'https://google.123',
      'https://127.0.0.1',
      'http://192.168.1.1',
      'https://[::1]',
      'https://[::ffff:8.8.8.8]',
      'https://[fe80::1%25eth0]',
      'https://${'a' * 64}.com',
      'https://${List.filled(5, 'a' * 60).join('.')}',
    ]) {
      test('blocks $url', () {
        final result = policy.validateUri(url);
        expect(result.isAllowed, isFalse);
        expect(result.reason, isNotNull);
      });
    }
  });

  test('URI reasons distinguish scheme, credentials, port and host', () {
    expect(
      policy.validateUri('ftp://google.com').reason,
      DestinationBlockReason.unsupportedScheme,
    );
    expect(
      policy.validateUri('https://').reason,
      DestinationBlockReason.emptyHost,
    );
    expect(
      policy.validateUri('https://a@google.com').reason,
      DestinationBlockReason.credentials,
    );
    expect(
      policy.validateUri('https://google.com:8080').reason,
      DestinationBlockReason.forbiddenPort,
    );
    expect(
      policy.validateUri('https://localhost').reason,
      DestinationBlockReason.internalHost,
    );
    expect(
      policy.validateUri('https://printer').reason,
      DestinationBlockReason.singleLabelHost,
    );
    expect(
      policy.validateUri('https://google.com.').reason,
      DestinationBlockReason.ambiguousHost,
    );
  });

  test(
    'DNS empty, all public, duplicates, mixed families and forbidden entries',
    () {
      expect(
        policy.validateResolvedAddresses([]).reason,
        DestinationBlockReason.emptyResolution,
      );
      for (final addresses in [
        ['8.8.8.8'],
        ['1.1.1.1', '8.8.8.8'],
        ['8.8.8.8', '8.8.8.8'],
        ['8.8.8.8', '2606:4700:4700::1111'],
      ]) {
        expect(policy.validateResolvedAddresses(addresses).isAllowed, isTrue);
      }
      for (final bad in [
        '127.0.0.1',
        '10.0.0.1',
        '169.254.169.254',
        '::1',
        'fc00::1',
        '::ffff:8.8.8.8',
        'invalid',
        'fe80::1%eth0',
      ]) {
        for (final addresses in [
          ['8.8.8.8', bad],
          [bad, '8.8.8.8'],
        ]) {
          expect(
            policy.validateResolvedAddresses(addresses).isAllowed,
            isFalse,
          );
          expect(
            policy.validateResolvedAddresses(addresses).reason,
            policy.validateAddress(bad).reason,
          );
        }
      }
    },
  );

  test('does not mutate the supplied resolution list', () {
    final addresses = ['8.8.8.8', '127.0.0.1'];
    policy.validateResolvedAddresses(addresses);
    expect(addresses, ['8.8.8.8', '127.0.0.1']);
  });
}
