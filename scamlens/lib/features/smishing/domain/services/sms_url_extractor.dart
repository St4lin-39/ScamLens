import '../../../../shared/url_processing/domain/services/web_url_recognizer.dart';

/// Extracts supported web links without normalizing or expanding them.
class SmsUrlExtractor {
  static final _candidates = RegExp(
    r'''(?<![\p{L}\p{N}\p{M}_@./:\-+%])(?:https?://|[a-z0-9])[^\s<>"'“”‘’]*''',
    caseSensitive: false,
    unicode: true,
  );

  List<String> extract(String text) {
    final urls = <String>[];
    for (final match in _candidates.allMatches(text)) {
      final candidate = _trimPunctuation(match.group(0)!);
      if (WebUrlRecognizer.isWebUrl(candidate)) urls.add(candidate);
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
}
