abstract class UrlExpander {
  /// Expands an already normalized URL, returning the last reached URL on failure.
  Future<String> expandUrl(String url);
}
