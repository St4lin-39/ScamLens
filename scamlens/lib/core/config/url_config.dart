class UrlConfig {
  /// Tiempo límite para resolver una redirección
  static const Duration requestTimeout = Duration(seconds: 4);

  /// Límite máximo de saltos para evitar bucles de redirección infinitos
  static const int maxRedirects = 5;

  /// Catálogo de servicios acortadores comunes
  static const Set<String> knownShorteners = {
    'bit.ly',
    'tinyurl.com',
    't.co',
    'goo.gl',
    'is.gd',
    'ow.ly',
    'cutt.ly',
    'rb.gy',
    'rebrand.ly',
    't.ly',
    'shorturl.at',
    'v.gd',
    'qr.ae',
  };

  /// Parámetros de rastreo que ensucian la URL y deben ser removidos
  static const Set<String> trackingParameters = {
    'utm_source',
    'utm_medium',
    'utm_campaign',
    'utm_term',
    'utm_content',
    'fbclid',
    'gclid',
    '_ga',
    'mc_cid',
    'mc_eid',
  };
}
