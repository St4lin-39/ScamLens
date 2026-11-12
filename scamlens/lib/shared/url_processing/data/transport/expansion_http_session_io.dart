import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import 'expansion_http_session.dart';
import 'public_address_policy.dart';

typedef ExpansionAddressResolver = Future<List<InternetAddress>> Function(
  String host,
);
typedef ExpansionSocketConnector = Future<ConnectionTask<Socket>> Function(
  InternetAddress address,
  int port,
);
typedef ExpansionTlsUpgrader = Future<Socket> Function(
  Socket socket, {
  required String hostname,
  required bool Function(X509Certificate) onBadCertificate,
});

ExpansionHttpSession createSession() => NativeExpansionHttpSession();

Future<List<InternetAddress>> _resolve(String host) =>
    InternetAddress.lookup(host);
Future<ConnectionTask<Socket>> _connect(InternetAddress address, int port) =>
    Socket.startConnect(address, port);
Future<Socket> _secure(
  Socket socket, {
  required String hostname,
  required bool Function(X509Certificate) onBadCertificate,
}) => SecureSocket.secure(
  socket,
  host: hostname,
  context: SecurityContext(withTrustedRoots: true),
  onBadCertificate: onBadCertificate,
  supportedProtocols: ['http/1.1'],
);

/// Native transport. Injection points are trusted infrastructure, not user input.
/// Production uses only literal-IP TCP and hostname-verified TLS above.
/// Closing cannot stop the OS DNS lookup itself; late results are discarded.
/// No global budget or redirect algorithm: those belong to the next stage.
final class NativeExpansionHttpSession implements ExpansionHttpSession {
  final PublicAddressPolicy policy;
  final ExpansionAddressResolver _resolver;
  final ExpansionSocketConnector _connector;
  final ExpansionTlsUpgrader _tlsUpgrader;
  final _operations = <_Operation>{};
  bool _closed = false;

  NativeExpansionHttpSession({
    this.policy = const PublicAddressPolicy(),
    ExpansionAddressResolver? resolver,
    ExpansionSocketConnector? connector,
    ExpansionTlsUpgrader? tlsUpgrader,
  }) : _resolver = resolver ?? _resolve,
       _connector = connector ?? _connect,
       _tlsUpgrader = tlsUpgrader ?? _secure;

  @override
  Future<ExpansionHttpResponse> send(
    String method,
    String url, {
    Duration timeout = const Duration(seconds: 4),
  }) async {
    if (_closed) {
      throw const ExpansionTransportException(
        ExpansionTransportFailure.cancelled,
      );
    }
    if (method != 'HEAD' && method != 'GET') {
      throw const ExpansionTransportException(
        ExpansionTransportFailure.unsupportedMethod,
      );
    }
    final decision = policy.validateUri(url);
    if (!decision.isAllowed) {
      throw ExpansionTransportException(
        ExpansionTransportFailure.blocked,
        blockReason: decision.reason,
      );
    }
    if (timeout <= Duration.zero) {
      throw const ExpansionTransportException(
        ExpansionTransportFailure.timeout,
      );
    }
    final operation = _Operation();
    _operations.add(operation);
    operation.onClose = () => _operations.remove(operation);
    try {
      return await _send(operation, method, Uri.parse(url)).timeout(timeout);
    } on TimeoutException catch (error) {
      operation.close();
      throw ExpansionTransportException(
        ExpansionTransportFailure.timeout,
        cause: error,
      );
    } catch (_) {
      operation.close();
      rethrow;
    }
  }

  Future<ExpansionHttpResponse> _send(
    _Operation operation,
    String method,
    Uri uri,
  ) async {
    final host = uri.host.replaceAll('[', '').replaceAll(']', '');
    final literal = InternetAddress.tryParse(host);
    final List<InternetAddress> addresses;
    try {
      addresses = literal != null
          ? [literal]
          : List.of(await operation.wait(_resolver(host)));
    } on ExpansionTransportException {
      rethrow;
    } catch (error) {
      throw ExpansionTransportException(
        ExpansionTransportFailure.dns,
        cause: error,
      );
    }
    operation.ensureOpen();
    final decision = policy.validateResolvedAddresses(
      addresses.map((address) => address.address),
    );
    if (!decision.isAllowed) {
      throw ExpansionTransportException(
        ExpansionTransportFailure.blocked,
        blockReason: decision.reason,
      );
    }
    // Recreate a literal address: do not pass the hostname to the connector.
    final approved = InternetAddress(addresses.first.address);
    final nativeClient = HttpClient();
    nativeClient.findProxy = (_) => 'DIRECT';
    nativeClient.authenticate = (_, _, _) async => false;
    nativeClient.authenticateProxy = (_, _, _, _) async => false;
    nativeClient.autoUncompress = false;
    final client = IOClient(nativeClient);
    operation.client = client;
    nativeClient.connectionFactory = (target, proxyHost, proxyPort) async {
      operation.ensureOpen();
      if (proxyHost != null ||
          proxyPort != null ||
          target.host != uri.host ||
          target.port != uri.port ||
          target.scheme != uri.scheme) {
        throw const ExpansionTransportException(
          ExpansionTransportFailure.blocked,
          blockReason: DestinationBlockReason.ambiguousHost,
        );
      }
      final future = _openSocket(
        operation,
        approved,
        uri.port,
        host,
        uri.scheme == 'https',
      );
      // HttpClient subscribes to task.socket after this factory completes.
      // Observe early failures now; the original future still propagates them
      // through send(), preserving the typed error instead of a zone error.
      future.ignore();
      return ConnectionTask.fromSocket(future, operation.close);
    };
    final request = http.Request(method, uri)
      ..followRedirects = false
      ..maxRedirects = 0
      ..persistentConnection = false;
    // Keep the original URI: HttpClient generates Host from its hostname/port,
    // not from approved.address. No caller-controlled headers are accepted.
    try {
      final response = await operation.wait(client.send(request));
      operation.ensureOpen();
      return _NativeResponse(response, operation);
    } on ExpansionTransportException {
      rethrow;
    } on TlsException catch (error) {
      throw ExpansionTransportException(
        ExpansionTransportFailure.tls,
        cause: error,
      );
    } on SocketException catch (error) {
      throw ExpansionTransportException(
        ExpansionTransportFailure.connection,
        cause: error,
      );
    } on http.ClientException catch (error) {
      throw ExpansionTransportException(
        ExpansionTransportFailure.http,
        cause: error,
      );
    }
  }

  Future<Socket> _openSocket(
    _Operation operation,
    InternetAddress address,
    int port,
    String host,
    bool secure,
  ) async {
    try {
      final task = await operation.wait(
        _connector(address, port),
        lateValue: (task) => task.cancel(),
      );
      operation.tasks.add(task);
      final socket = await operation.wait(
        task.socket,
        lateValue: (socket) => socket.destroy(),
      );
      operation.sockets.add(socket);
      operation.ensureOpen();
      if (!secure) return socket;
      try {
        final tls = await operation.wait(
          _tlsUpgrader(socket, hostname: host, onBadCertificate: (_) => false),
          lateValue: (socket) => socket.destroy(),
        );
        operation.sockets.add(tls);
        return tls;
      } on ExpansionTransportException {
        rethrow;
      } catch (error) {
        throw ExpansionTransportException(
          ExpansionTransportFailure.tls,
          cause: error,
        );
      }
    } on ExpansionTransportException {
      rethrow;
    } catch (error) {
      throw ExpansionTransportException(
        ExpansionTransportFailure.connection,
        cause: error,
      );
    }
  }

  @override
  void close() {
    if (_closed) return;
    _closed = true;
    for (final operation in _operations.toList()) {
      operation.close();
    }
  }
}

final class _Operation {
  final _cancelled = Completer<void>();
  final tasks = <ConnectionTask<Socket>>[];
  final sockets = <Socket>[];
  IOClient? client;
  void Function()? onClose;
  void Function()? closeResponse;
  bool get isClosed => _cancelled.isCompleted;

  void ensureOpen() {
    if (isClosed) {
      throw const ExpansionTransportException(
        ExpansionTransportFailure.cancelled,
      );
    }
  }

  Future<T> wait<T>(Future<T> future, {void Function(T)? lateValue}) {
    return Future.any([
      future.then((value) {
        if (isClosed) {
          lateValue?.call(value);
          throw const ExpansionTransportException(
            ExpansionTransportFailure.cancelled,
          );
        }
        return value;
      }),
      _cancelled.future.then<T>(
        (_) => throw const ExpansionTransportException(
          ExpansionTransportFailure.cancelled,
        ),
      ),
    ]);
  }

  void close() {
    if (isClosed) return;
    _cancelled.complete();
    for (final task in tasks) {
      task.cancel();
    }
    for (final socket in sockets) {
      socket.destroy();
    }
    client?.close();
    closeResponse?.call();
    onClose?.call();
  }
}

final class _NativeResponse implements ExpansionHttpResponse {
  final http.StreamedResponse _response;
  final _Operation _operation;
  StreamSubscription<List<int>>? _subscription;
  late final StreamController<List<int>> _body;
  bool _listened = false;
  @override
  final Map<String, String> headers;

  _NativeResponse(this._response, this._operation)
    : headers = Map.unmodifiable(_response.headers) {
    _body = StreamController<List<int>>(
      onListen: () {
        _listened = true;
        if (_operation.isClosed) {
          unawaited(_body.close());
          return;
        }
        _subscription = _response.stream.listen(
          _body.add,
          onError: (Object error, StackTrace stack) {
            _body.addError(error, stack);
            _operation.close();
          },
          onDone: _operation.close,
        );
      },
      onPause: () => _subscription?.pause(),
      onResume: () => _subscription?.resume(),
      onCancel: () {
        _operation.close();
        return _subscription?.cancel();
      },
    );
    _operation.closeResponse = () {
      // Cancel, never drain a GET body. Close even when nobody listened.
      _subscription ??= !_listened
          ? _response.stream.listen((_) {}, onError: (Object _) {})
          : null;
      unawaited(_subscription?.cancel());
      unawaited(_body.close());
    };
  }

  @override
  int get statusCode => _response.statusCode;
  @override
  Stream<List<int>> get body => _body.stream;
  @override
  Future<void> close() async {
    _operation.close();
    await _subscription?.cancel();
  }
}
