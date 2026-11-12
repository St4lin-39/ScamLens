/// Syntax recognition only: no DNS, reputation checks or TLD allowlist.
class WebUrlRecognizer {
  static final _label = RegExp(
    r'^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$',
    caseSensitive: false,
  );
  static final _tld = RegExp(r'^[a-z]{2,63}$', caseSensitive: false);
  static final _numericHost = RegExp(r'^[0-9.]+$');

  static bool hasHttpScheme(String value) =>
      RegExp(r'^https?://', caseSensitive: false).hasMatch(value);

  static bool isWebUrl(String value) {
    if (value.isEmpty || RegExp(r'\s').hasMatch(value)) return false;
    final explicit = hasHttpScheme(value);
    try {
      final uri = Uri.tryParse(explicit ? value : 'https://$value');
      if (uri == null ||
          !uri.hasAuthority ||
          uri.userInfo.isNotEmpty ||
          uri.host.isEmpty ||
          (uri.hasPort && (uri.port < 1 || uri.port > 65535))) {
        return false;
      }
      final host = uri.host;
      // Uri parsing validates bracketed IPv6; only explicit URLs support it.
      if (host.contains(':')) return explicit;
      final labels = host.split('.');
      if (_numericHost.hasMatch(host)) {
        return labels.length == 4 &&
            labels.every(
              (part) =>
                  RegExp(r'^(0|[1-9][0-9]{0,2})$').hasMatch(part) &&
                  int.parse(part) <= 255,
            ) &&
            (explicit || uri.path.startsWith('/') && uri.path.length > 1);
      }
      return host.length <= 253 &&
          labels.length >= (host.startsWith('www.') ? 3 : 2) &&
          labels.every((part) => part.length <= 63 && _label.hasMatch(part)) &&
          (_tld.hasMatch(labels.last) ||
              labels.last.startsWith('xn--') && labels.last.length > 4);
    } on FormatException {
      return false;
    }
  }
}
