import 'expansion_http_session.dart';

ExpansionHttpSession createSession() => UnsupportedExpansionHttpSession();

/// No browser client, fetch, DNS or socket dependency. Fail closed on Web.
final class UnsupportedExpansionHttpSession implements ExpansionHttpSession {
  bool _closed = false;

  @override
  Future<ExpansionHttpResponse> send(
    String method,
    String url, {
    Duration timeout = const Duration(seconds: 4),
  }) async {
    throw ExpansionTransportException(
      _closed
          ? ExpansionTransportFailure.cancelled
          : ExpansionTransportFailure.unsupportedPlatform,
    );
  }

  @override
  void close() => _closed = true;
}
