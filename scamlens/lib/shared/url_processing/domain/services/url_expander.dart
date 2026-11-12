import '../entities/url_expansion_result.dart';

abstract class UrlExpander {
  /// Expands an absolute HTTP(S) URL, preserving its query for requests.
  /// Only a resolved result confirms a destination; this is no safety verdict.
  Future<UrlExpansionResult> expandUrl(String url);
}
