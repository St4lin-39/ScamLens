/// Extracts supported web links without normalizing or expanding them.
class SmsUrlExtractor {
  static final _candidates = RegExp(
    r'''(?<![\w@./:\-])(?:https?://|www\.)[^\s<>"'“”‘’]+''',
    caseSensitive: false,
  );
  static final _hostLabel = RegExp(
    r'^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$',
    caseSensitive: false,
  );

  List<String> extract(String text) {
    final urls = <String>[];
    for (final match in _candidates.allMatches(text)) {
      final candidate = _trimPunctuation(match.group(0)!);
      if (_isValid(candidate)) urls.add(candidate);
    }
    return List.unmodifiable(urls);
  }

  String _trimPunctuation(String value) {
    const closers = {')': '(', ']': '[', '}': '{'};
    while (value.isNotEmpty) {
      final last = value[value.length - 1];
      if ('.,!?:;'.contains(last)) {
        value = value.substring(0, value.length - 1);
        continue;
      }
      final opener = closers[last];
      if (opener != null &&
          last.allMatches(value).length > opener.allMatches(value).length) {
        value = value.substring(0, value.length - 1);
        continue;
      }
      break;
    }
    return value;
  }

  bool _isValid(String value) {
    final hasWww = value.toLowerCase().startsWith('www.');
    final uri = Uri.tryParse(hasWww ? 'https://$value' : value);
    if (uri == null || !uri.hasAuthority || uri.host.isEmpty) return false;
    // Accessing the port can throw for malformed authorities.
    try {
      if (uri.hasPort && (uri.port < 1 || uri.port > 65535)) return false;
    } on FormatException {
      return false;
    }
    // Uri exposes IPv6 hosts without their surrounding brackets.
    if (uri.host.contains(':')) return true;
    final labels = uri.host.split('.');
    return labels.length >= (hasWww ? 3 : 2) &&
        uri.host.length <= 253 &&
        labels.every(
          (label) => label.length <= 63 && _hostLabel.hasMatch(label),
        );
  }
}
