import 'public_address_policy.dart';

enum ExpansionTransportFailure {
  blocked,
  unsupportedPlatform,
  unsupportedMethod,
  cancelled,
  timeout,
  dns,
  connection,
  tls,
  http,
}

final class ExpansionTransportException implements Exception {
  final ExpansionTransportFailure failure;
  final DestinationBlockReason? blockReason;
  final Object? cause;

  const ExpansionTransportException(
    this.failure, {
    this.blockReason,
    this.cause,
  });

  @override
  String toString() => 'ExpansionTransportException($failure, $blockReason)';
}

/// Data-only seam. Create one session per expansion and always close it.
/// Requests have no caller headers/body/credentials and never follow redirects.
abstract interface class ExpansionHttpSession {
  /// Deadline covers DNS, TCP, TLS and response headers, not body consumption.
  /// A later global expansion budget must close the session when it expires.
  Future<ExpansionHttpResponse> send(
    String method,
    String url, {
    Duration timeout = const Duration(seconds: 4),
  });

  /// Idempotent. Abort pending requests and prevent further connections.
  void close();
}

abstract interface class ExpansionHttpResponse {
  int get statusCode;
  Map<String, String> get headers;
  Stream<List<int>> get body;

  /// Cancel instead of draining: callers need only headers for expansion.
  Future<void> close();
}

typedef ExpansionHttpSessionFactory = ExpansionHttpSession Function();
