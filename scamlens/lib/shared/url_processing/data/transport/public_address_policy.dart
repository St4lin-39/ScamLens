/// Reasons for refusing a request destination, not maliciousness verdicts.
enum DestinationBlockReason {
  invalidUri,
  unsupportedScheme,
  emptyHost,
  credentials,
  internalHost,
  singleLabelHost,
  forbiddenPort,
  ambiguousHost,
  invalidAddress,
  scopedAddress,
  specialUseAddress,
  unallocatedAddress,
  emptyResolution,
}

final class DestinationDecision {
  final DestinationBlockReason? reason;
  bool get isAllowed => reason == null;

  const DestinationDecision.allowed() : reason = null;
  const DestinationDecision.blocked(DestinationBlockReason this.reason);
}

/// Pure syntax/address policy: no DNS, sockets, HTTP or reputation checks.
///
/// URI approval and resolution approval are separate requirements. Neither pins
/// a connection or prevents DNS rebinding. Stage 3 must connect to the approved
/// IP without resolving again, preserving hostname TLS verification.
///
/// IANA snapshot reviewed 2026-11-12 (registries updated October 2025):
/// https://www.iana.org/assignments/iana-ipv4-special-registry/
/// https://www.iana.org/assignments/iana-ipv6-special-registry/
/// https://www.iana.org/assignments/ipv6-unicast-address-assignments/
/// Update these tables when allocations change. This is a conservative policy,
/// not proof of live global routability. Only ports 80/443 are supported; valid
/// sites on other ports are deliberately unavailable. No transport is wired yet.
final class PublicAddressPolicy {
  const PublicAddressPolicy();

  static const _allowed = DestinationDecision.allowed();
  static final _label = RegExp(r'^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$');
  static final _v4Literal = RegExp(
    r'^(0|[1-9][0-9]{0,2})(\.(0|[1-9][0-9]{0,2})){3}$',
  );
  static final _numericLabel = RegExp(r'^(?:[0-9]+|0x[0-9a-f]+)$');
  static const _internalSuffixes = [
    'localhost',
    'local',
    'localdomain',
    'internal',
    'intranet',
    'lan',
    'home',
    'corp',
    'test',
    'invalid',
    'example',
    'onion',
    'arpa',
    'example.com',
    'example.net',
    'example.org',
  ];

  /// Validate the original text, before a parser can erase ambiguous spellings.
  /// Bare Unicode names must first be converted to ASCII IDNA by a future caller;
  /// this policy does not implement IDNA or infer schemes.
  DestinationDecision validateUri(String value) {
    if (value.isEmpty || RegExp(r'[\x00-\x20\x7f\\]').hasMatch(value)) {
      return const DestinationDecision.blocked(
        DestinationBlockReason.invalidUri,
      );
    }
    final Uri uri;
    try {
      uri = Uri.parse(value);
    } on FormatException {
      return const DestinationDecision.blocked(
        DestinationBlockReason.invalidUri,
      );
    }
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      return const DestinationDecision.blocked(
        DestinationBlockReason.unsupportedScheme,
      );
    }
    if (!uri.hasAuthority || uri.host.isEmpty) {
      return const DestinationDecision.blocked(
        DestinationBlockReason.emptyHost,
      );
    }
    final authority = value
        .substring(value.indexOf('://') + 3)
        .split(RegExp(r'[/\?#]'))
        .first;
    if (uri.userInfo.isNotEmpty || authority.contains('@')) {
      return const DestinationDecision.blocked(
        DestinationBlockReason.credentials,
      );
    }
    // Encoded hosts, empty/zero-padded ports, trailing dots and Unicode hosts
    // can be interpreted differently by parsers/resolvers. Reject, don't repair.
    if (authority.contains('%')) {
      return const DestinationDecision.blocked(
        DestinationBlockReason.ambiguousHost,
      );
    }
    final portText = authority.startsWith('[')
        ? authority.substring(authority.indexOf(']') + 1)
        : authority.contains(':')
        ? authority.substring(authority.lastIndexOf(':'))
        : '';
    if (portText.isNotEmpty && portText != ':80' && portText != ':443') {
      return const DestinationDecision.blocked(
        DestinationBlockReason.forbiddenPort,
      );
    }
    if (uri.port != 80 && uri.port != 443) {
      return const DestinationDecision.blocked(
        DestinationBlockReason.forbiddenPort,
      );
    }
    var host = uri.host.toLowerCase();
    if (host.startsWith('[') && host.endsWith(']')) {
      host = host.substring(1, host.length - 1);
    }
    if (host.contains(':') || RegExp(r'^[0-9.]+$').hasMatch(host)) {
      return validateAddress(host);
    }
    if (host.length > 253 || host.endsWith('.') || host.contains('%')) {
      return const DestinationDecision.blocked(
        DestinationBlockReason.ambiguousHost,
      );
    }
    if (_internalSuffixes.any(
      (suffix) => host == suffix || host.endsWith('.$suffix'),
    )) {
      return const DestinationDecision.blocked(
        DestinationBlockReason.internalHost,
      );
    }
    final labels = host.split('.');
    if (labels.length == 1) {
      return const DestinationDecision.blocked(
        DestinationBlockReason.singleLabelHost,
      );
    }
    if (!labels.every((label) => _label.hasMatch(label)) ||
        _numericLabel.hasMatch(labels.last)) {
      return const DestinationDecision.blocked(
        DestinationBlockReason.ambiguousHost,
      );
    }
    return _allowed;
  }

  /// Strict literal IP, without brackets, port, zone ID or hostname.
  DestinationDecision validateAddress(String address) {
    if (address.contains('%')) {
      return const DestinationDecision.blocked(
        DestinationBlockReason.scopedAddress,
      );
    }
    final bytes = _parseAddress(address);
    if (bytes == null) {
      return const DestinationDecision.blocked(
        DestinationBlockReason.invalidAddress,
      );
    }
    if (bytes.length == 4) {
      if (_v4PublicExceptions.any((prefix) => prefix.contains(bytes))) {
        return _allowed;
      }
      if (_v4Blocked.any((prefix) => prefix.contains(bytes))) {
        return const DestinationDecision.blocked(
          DestinationBlockReason.specialUseAddress,
        );
      }
      return _allowed;
    }
    // Mapped/compatible IPv4, NAT64, Teredo, 6to4, ORCHID and DETs are
    // intentionally not approved, even where IANA marks a mechanism global.
    if (_v6SpecialExceptions.any((prefix) => prefix.contains(bytes))) {
      return _allowed;
    }
    if (_v6Blocked.any((prefix) => prefix.contains(bytes))) {
      return const DestinationDecision.blocked(
        DestinationBlockReason.specialUseAddress,
      );
    }
    if (!_v6Allocated.any((prefix) => prefix.contains(bytes))) {
      return const DestinationDecision.blocked(
        DestinationBlockReason.unallocatedAddress,
      );
    }
    return _allowed;
  }

  /// Caller supplies the complete A/AAAA result. One forbidden or invalid
  /// address rejects the whole destination. No filtering to a public subset.
  DestinationDecision validateResolvedAddresses(Iterable<String> addresses) {
    var hasAddress = false;
    for (final address in addresses) {
      hasAddress = true;
      final decision = validateAddress(address);
      if (!decision.isAllowed) return decision;
    }
    return hasAddress
        ? _allowed
        : const DestinationDecision.blocked(
            DestinationBlockReason.emptyResolution,
          );
  }

  static List<int>? _parseAddress(String address) {
    try {
      if (address.contains(':')) {
        if (!RegExp(r'^[0-9a-fA-F:.]+$').hasMatch(address)) return null;
        // Reject ambiguous dotted tails even in IPv6 notation.
        if (address.contains('.') &&
            !_v4Literal.hasMatch(
              address.substring(address.lastIndexOf(':') + 1),
            )) {
          return null;
        }
        return Uri.parseIPv6Address(address);
      }
      if (!_v4Literal.hasMatch(address)) return null;
      return Uri.parseIPv4Address(address);
    } on FormatException {
      return null;
    }
  }

  static List<_Prefix> _prefixes(List<String> values) =>
      values.map(_Prefix.parse).toList(growable: false);
  static final _v4PublicExceptions = _prefixes([
    '192.0.0.9/32',
    '192.0.0.10/32',
  ]);
  static final _v4Blocked = _prefixes([
    '0.0.0.0/8',
    '10.0.0.0/8',
    '100.64.0.0/10',
    '127.0.0.0/8',
    '169.254.0.0/16',
    '172.16.0.0/12',
    '192.0.0.0/24',
    '192.0.2.0/24',
    '192.88.99.0/24',
    '192.168.0.0/16',
    '198.18.0.0/15',
    '198.51.100.0/24',
    '203.0.113.0/24',
    '224.0.0.0/4',
    '240.0.0.0/4',
  ]);
  static final _v6SpecialExceptions = _prefixes([
    '2001:1::1/128',
    '2001:1::2/128',
    '2001:1::3/128',
    '2001:3::/32',
    '2001:4:112::/48',
  ]);
  static final _v6Blocked = _prefixes([
    '::/96',
    '::ffff:0:0/96',
    '64:ff9b::/96',
    '64:ff9b:1::/48',
    '100::/64',
    '100:0:0:1::/64',
    '2001::/23',
    '2001:db8::/32',
    '2002::/16',
    '3fff::/20',
    '5f00::/16',
    'fc00::/7',
    'fe80::/10',
    'ff00::/8',
  ]);
  // Only ALLOCATED entries, not all of 2000::/3. Special-use exclusions above
  // take precedence. This permits normal public neighbors of special ranges.
  static final _v6Allocated = _prefixes([
    '2001:200::/23',
    '2001:400::/23',
    '2001:600::/23',
    '2001:800::/22',
    '2001:c00::/23',
    '2001:e00::/23',
    '2001:1200::/23',
    '2001:1400::/22',
    '2001:1800::/23',
    '2001:1a00::/23',
    '2001:1c00::/22',
    '2001:2000::/19',
    '2001:4000::/23',
    '2001:4200::/23',
    '2001:4400::/23',
    '2001:4600::/23',
    '2001:4800::/23',
    '2001:4a00::/23',
    '2001:4c00::/23',
    '2001:5000::/20',
    '2001:8000::/19',
    '2001:a000::/20',
    '2001:b000::/20',
    '2003::/18',
    '2400::/12',
    '2410::/12',
    '2600::/12',
    '2610::/23',
    '2620::/23',
    '2630::/12',
    '2800::/12',
    '2a00::/12',
    '2a10::/12',
    '2c00::/12',
  ]);
}

/// Byte-wise matching avoids 32/128-bit integer and JavaScript bitwise limits.
final class _Prefix {
  final List<int> bytes;
  final int bits;
  _Prefix.parse(String cidr)
    : bytes = PublicAddressPolicy._parseAddress(cidr.split('/').first)!,
      bits = int.parse(cidr.split('/').last);

  bool contains(List<int> address) {
    if (address.length != bytes.length) return false;
    final fullBytes = bits ~/ 8;
    for (var i = 0; i < fullBytes; i++) {
      if (address[i] != bytes[i]) return false;
    }
    final remainder = bits % 8;
    if (remainder == 0) return true;
    final mask = (0xff << (8 - remainder)) & 0xff;
    return address[fullBytes] & mask == bytes[fullBytes] & mask;
  }
}
