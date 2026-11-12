@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:scamlens/shared/url_processing/data/transport/expansion_http_session.dart';
import 'package:scamlens/shared/url_processing/data/transport/expansion_http_session_io.dart';
import 'package:scamlens/shared/url_processing/data/transport/public_address_policy.dart';

const _hostname = 'expansion.scamlens.net';
const _url = 'http://$_hostname/path?q=1';
const _fixture =
    'test/shared/url_processing/data/transport/fixtures/localhost_test';

Matcher failure(ExpansionTransportFailure value) => throwsA(
  isA<ExpansionTransportException>().having((e) => e.failure, 'failure', value),
);

Future<List<InternetAddress>> publicDns(String _) async => [
  InternetAddress('8.8.8.8'),
];

// Only these tests redirect the approved public address to a controlled local
// server. The production connector never performs this substitution.
Future<HttpServer> localServer(void Function(HttpRequest) handler) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen(handler);
  addTearDown(() => server.close(force: true));
  return server;
}

Future<ConnectionTask<Socket>> localConnect(HttpServer server) =>
    Socket.startConnect(InternetAddress.loopbackIPv4, server.port);

void main() {
  for (final method in ['HEAD', 'GET']) {
    test(
      '$method pins selected IP, preserves Host/path and disables redirects',
      () async {
        final received = Completer<HttpRequest>();
        var requests = 0;
        final server = await localServer((request) {
          requests++;
          received.complete(request);
          request.response.statusCode = 302;
          request.response.headers.set('location', 'http://127.0.0.1/blocked');
          request.response.close();
        });
        var resolutions = 0;
        final connections = <String>[];
        final session = NativeExpansionHttpSession(
          resolver: (host) async {
            expect(host, _hostname);
            resolutions++;
            return [InternetAddress('8.8.8.8'), InternetAddress('1.1.1.1')];
          },
          connector: (address, port) {
            connections.add(address.address);
            expect(address.host, '8.8.8.8');
            expect(port, 80);
            return localConnect(server);
          },
        );
        addTearDown(session.close);
        final response = await session.send(method, _url);
        expect(response.statusCode, 302);
        expect(response.headers['location'], 'http://127.0.0.1/blocked');
        final request = await received.future;
        expect(request.method, method);
        expect(request.uri.toString(), '/path?q=1');
        expect(request.headers.value('host'), _hostname);
        expect(request.headers.value('cookie'), isNull);
        expect(request.headers.value('authorization'), isNull);
        expect(request.headers.value('proxy-authorization'), isNull);
        expect(connections, ['8.8.8.8']);
        expect(resolutions, 1);
        expect(requests, 1);
        await response.close();
      },
    );
  }

  for (final addresses in [
    <String>[],
    ['127.0.0.1'],
    ['10.0.0.1'],
    ['8.8.8.8', '192.168.0.1'],
    ['8.8.8.8', 'fc00::1'],
  ]) {
    test('blocks DNS $addresses before connecting', () async {
      var connected = false;
      final session = NativeExpansionHttpSession(
        resolver: (_) async => addresses.map(InternetAddress.new).toList(),
        connector: (_, _) async {
          connected = true;
          throw StateError('must not connect');
        },
      );
      addTearDown(session.close);
      await expectLater(
        session.send('HEAD', _url),
        failure(ExpansionTransportFailure.blocked),
      );
      expect(connected, isFalse);
    });
  }

  test('invalid URI and embedded credentials are blocked before DNS', () async {
    var resolved = false;
    final session = NativeExpansionHttpSession(
      resolver: (_) async {
        resolved = true;
        return [];
      },
    );
    addTearDown(session.close);
    for (final url in [
      'ftp://$_hostname',
      'https://a:b@$_hostname',
      'http://localhost',
      'https://$_hostname:8080',
    ]) {
      await expectLater(
        session.send('HEAD', url),
        failure(ExpansionTransportFailure.blocked),
      );
    }
    expect(resolved, isFalse);
  });

  test('blocked resolution keeps its typed policy reason', () async {
    final session = NativeExpansionHttpSession(resolver: (_) async => []);
    addTearDown(session.close);
    await expectLater(
      session.send('HEAD', _url),
      throwsA(
        isA<ExpansionTransportException>().having(
          (e) => e.blockReason,
          'reason',
          DestinationBlockReason.emptyResolution,
        ),
      ),
    );
  });

  test(
    'public literal bypasses DNS and is passed as InternetAddress',
    () async {
      final server = await localServer((r) => r.response.close());
      var resolved = false;
      final session = NativeExpansionHttpSession(
        resolver: (_) async {
          resolved = true;
          return [];
        },
        connector: (address, port) {
          expect(address.address, '1.1.1.1');
          return localConnect(server);
        },
      );
      addTearDown(session.close);
      final response = await session.send('HEAD', 'http://1.1.1.1');
      expect(resolved, isFalse);
      await response.close();
    },
  );

  test(
    'only HEAD/GET and positive per-request deadlines are accepted',
    () async {
      final session = NativeExpansionHttpSession(
        resolver: (_) async => throw StateError('no DNS'),
      );
      addTearDown(session.close);
      await expectLater(
        session.send('POST', _url),
        failure(ExpansionTransportFailure.unsupportedMethod),
      );
      await expectLater(
        session.send('GET', _url, timeout: Duration.zero),
        failure(ExpansionTransportFailure.timeout),
      );
    },
  );

  test('DNS error and connection error remain distinguishable', () async {
    final dns = NativeExpansionHttpSession(
      resolver: (_) async => throw const SocketException('DNS failed'),
    );
    final tcp = NativeExpansionHttpSession(
      resolver: publicDns,
      connector: (_, _) async => throw const SocketException('TCP failed'),
    );
    addTearDown(dns.close);
    addTearDown(tcp.close);
    await expectLater(
      dns.send('HEAD', _url),
      failure(ExpansionTransportFailure.dns),
    );
    await expectLater(
      tcp.send('HEAD', _url),
      failure(ExpansionTransportFailure.connection),
    );
  });

  for (final lateError in [false, true]) {
    test(
      'close during DNS discards late ${lateError ? 'error' : 'result'}',
      () async {
        final pending = Completer<List<InternetAddress>>();
        var connected = false;
        final session = NativeExpansionHttpSession(
          resolver: (_) => pending.future,
          connector: (_, _) async {
            connected = true;
            throw StateError('no connection');
          },
        );
        final result = session.send('HEAD', _url);
        final expectation = expectLater(
          result,
          failure(ExpansionTransportFailure.cancelled),
        );
        session.close();
        session.close();
        await expectation;
        if (lateError) {
          pending.completeError(const SocketException('late DNS'));
        } else {
          pending.complete([InternetAddress('8.8.8.8')]);
        }
        await Future<void>.delayed(Duration.zero);
        expect(connected, isFalse);
        await expectLater(
          session.send('HEAD', _url),
          failure(ExpansionTransportFailure.cancelled),
        );
      },
    );
  }

  test(
    'DNS timeout discards late result and leaves session reusable',
    () async {
      final pending = Completer<List<InternetAddress>>();
      var calls = 0;
      var connected = false;
      final session = NativeExpansionHttpSession(
        resolver: (_) {
          calls++;
          return calls == 1 ? pending.future : Future.value([]);
        },
        connector: (_, _) async {
          connected = true;
          throw StateError('no connection');
        },
      );
      addTearDown(session.close);
      await expectLater(
        session.send('HEAD', _url, timeout: const Duration(milliseconds: 20)),
        failure(ExpansionTransportFailure.timeout),
      );
      pending.complete([InternetAddress('8.8.8.8')]);
      await Future<void>.delayed(Duration.zero);
      expect(calls, 1);
      expect(connected, isFalse);
      await expectLater(
        session.send('HEAD', _url),
        failure(ExpansionTransportFailure.blocked),
      );
      expect(calls, 2);
    },
  );

  test('late connector task is cancelled after session close', () async {
    final pending = Completer<ConnectionTask<Socket>>();
    final started = Completer<void>();
    var cancelled = false;
    final session = NativeExpansionHttpSession(
      resolver: publicDns,
      connector: (_, _) {
        started.complete();
        return pending.future;
      },
    );
    final result = session.send('HEAD', _url);
    final expectation = expectLater(
      result,
      failure(ExpansionTransportFailure.cancelled),
    );
    await started.future;
    session.close();
    await expectation;
    final socket = _SocketDouble();
    pending.complete(
      ConnectionTask.fromSocket(Future.value(socket), () {
        cancelled = true;
        socket.destroy();
      }),
    );
    await Future<void>.delayed(Duration.zero);
    expect(cancelled, isTrue);
    expect(socket.destroyed, isTrue);
  });

  test(
    'close pending socket completes promptly and destroys late socket',
    () async {
      final pending = Completer<Socket>();
      final started = Completer<void>();
      var cancellations = 0;
      final session = NativeExpansionHttpSession(
        resolver: publicDns,
        connector: (_, _) async {
          started.complete();
          return ConnectionTask.fromSocket(pending.future, () {
            cancellations++;
          });
        },
      );
      final result = session.send('HEAD', _url);
      final expectation = expectLater(
        result,
        failure(ExpansionTransportFailure.cancelled),
      );
      await started.future;
      await Future<void>.delayed(Duration.zero);
      session.close();
      await expectation;
      final socket = _SocketDouble();
      pending.complete(socket);
      await Future<void>.delayed(Duration.zero);
      expect(cancellations, greaterThan(0));
      expect(socket.destroyed, isTrue);
    },
  );

  test(
    'TLS receives original hostname and strict rejection callback',
    () async {
      final socket = _SocketDouble();
      final session = NativeExpansionHttpSession(
        resolver: publicDns,
        connector: (_, port) async {
          expect(port, 443);
          return ConnectionTask.fromSocket(Future.value(socket), () {});
        },
        tlsUpgrader:
            (received, {required hostname, required onBadCertificate}) async {
              expect(received, same(socket));
              expect(hostname, _hostname);
              expect(onBadCertificate(_CertificateDouble()), isFalse);
              throw const HandshakeException('invalid certificate');
            },
      );
      addTearDown(session.close);
      await expectLater(
        session.send('HEAD', 'https://$_hostname'),
        failure(ExpansionTransportFailure.tls),
      );
      expect(socket.destroyed, isTrue);
    },
  );

  test('close during TLS destroys raw and late secure sockets', () async {
    final raw = _SocketDouble();
    final secure = _SocketDouble();
    final pending = Completer<Socket>();
    final started = Completer<void>();
    final session = NativeExpansionHttpSession(
      resolver: publicDns,
      connector: (_, _) async =>
          ConnectionTask.fromSocket(Future.value(raw), () {}),
      tlsUpgrader: (_, {required hostname, required onBadCertificate}) {
        started.complete();
        return pending.future;
      },
    );
    final result = session.send('HEAD', 'https://$_hostname');
    final expectation = expectLater(
      result,
      failure(ExpansionTransportFailure.cancelled),
    );
    await started.future;
    session.close();
    await expectation;
    pending.complete(secure);
    await Future<void>.delayed(Duration.zero);
    expect(raw.destroyed, isTrue);
    expect(secure.destroyed, isTrue);
  });

  test(
    'response streams bytes, has immutable headers and closes idempotently',
    () async {
      final server = await localServer((r) {
        r.response.write('hello');
        r.response.close();
      });
      final session = NativeExpansionHttpSession(
        resolver: publicDns,
        connector: (_, _) => localConnect(server),
      );
      addTearDown(session.close);
      final response = await session.send('GET', _url);
      expect(await utf8.decoder.bind(response.body).join(), 'hello');
      expect(() => response.headers['x'] = 'y', throwsUnsupportedError);
      await response.close();
      await response.close();
    },
  );

  test('closing GET response does not wait for an unfinished body', () async {
    final received = Completer<void>();
    final server = await localServer((r) {
      r.response.headers.chunkedTransferEncoding = true;
      r.response.write('first');
      r.response.flush();
      received.complete();
      // Deliberately never finish the body.
    });
    final session = NativeExpansionHttpSession(
      resolver: publicDns,
      connector: (_, _) => localConnect(server),
    );
    addTearDown(session.close);
    final response = await session.send('GET', _url);
    await received.future;
    await response.close().timeout(const Duration(seconds: 1));
    expect(await response.body.toList(), isEmpty);
  });

  test('closing one session leaves a separate expansion usable', () async {
    final server = await localServer((r) => r.response.close());
    NativeExpansionHttpSession create() => NativeExpansionHttpSession(
      resolver: publicDns,
      connector: (_, _) => localConnect(server),
    );
    final first = create();
    final second = create();
    addTearDown(first.close);
    addTearDown(second.close);
    first.close();
    await expectLater(
      first.send('HEAD', _url),
      failure(ExpansionTransportFailure.cancelled),
    );
    final response = await second.send('HEAD', _url);
    expect(response.statusCode, 200);
    second.close();
    expect(await response.body.toList(), isEmpty);
    await response.close();
  });

  test('no response headers triggers timeout and closes socket', () async {
    final peerClosed = Completer<void>();
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    server.listen((socket) {
      addTearDown(socket.destroy);
      socket.listen(
        (_) {},
        onDone: () {
          if (!peerClosed.isCompleted) peerClosed.complete();
        },
      );
    });
    final session = NativeExpansionHttpSession(
      resolver: publicDns,
      connector: (_, _) =>
          Socket.startConnect(InternetAddress.loopbackIPv4, server.port),
    );
    addTearDown(session.close);
    await expectLater(
      session.send('HEAD', _url, timeout: const Duration(milliseconds: 100)),
      failure(ExpansionTransportFailure.timeout),
    );
    await peerClosed.future.timeout(const Duration(seconds: 1));
  });

  test(
    'production TLS sends the original hostname in ClientHello SNI',
    () async {
      final observed = Completer<String>();
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(server.close);
      server.listen((socket) {
        addTearDown(socket.destroy);
        final bytes = <int>[];
        socket.listen((chunk) {
          bytes.addAll(chunk);
          if (bytes.length < 5 ||
              bytes.length < 5 + (bytes[3] << 8 | bytes[4])) {
            return;
          }
          if (!observed.isCompleted) observed.complete(_clientHelloSni(bytes));
          socket.destroy();
        }, onError: (Object _) {});
      });
      final session = NativeExpansionHttpSession(
        resolver: publicDns,
        connector: (_, _) =>
            Socket.startConnect(InternetAddress.loopbackIPv4, server.port),
      );
      addTearDown(session.close);
      final request = expectLater(
        session.send('HEAD', 'https://$_hostname'),
        failure(ExpansionTransportFailure.tls),
      );
      expect(
        await observed.future.timeout(const Duration(seconds: 2)),
        _hostname,
      );
      await request;
    },
  );

  test(
    'IPv6 literal is pinned without DNS and HTTP Host stays bracketed',
    () async {
      final host = Completer<String?>();
      final server = await localServer((r) {
        host.complete(r.headers.value('host'));
        r.response.close();
      });
      final session = NativeExpansionHttpSession(
        resolver: (_) async => throw StateError('literal must not resolve'),
        connector: (address, _) {
          expect(address.address, '2606:4700:4700::1111');
          expect(address.type, InternetAddressType.IPv6);
          return localConnect(server);
        },
      );
      addTearDown(session.close);
      final response = await session.send(
        'HEAD',
        'http://[2606:4700:4700::1111]',
      );
      expect(await host.future, '[2606:4700:4700::1111]');
      await response.close();
    },
  );

  for (final tls in [false, true]) {
    test(
      'timeout during ${tls ? 'TLS' : 'TCP'} cancels and destroys late sockets',
      () async {
        final pending = Completer<Socket>();
        final raw = _SocketDouble();
        final lateSocket = _SocketDouble();
        var cancellations = 0;
        final session = NativeExpansionHttpSession(
          resolver: publicDns,
          connector: (_, _) async => ConnectionTask.fromSocket(
            tls ? Future.value(raw) : pending.future,
            () {
              cancellations++;
            },
          ),
          tlsUpgrader: (_, {required hostname, required onBadCertificate}) =>
              pending.future,
        );
        addTearDown(session.close);
        await expectLater(
          session.send(
            'HEAD',
            '${tls ? 'https' : 'http'}://$_hostname',
            timeout: const Duration(milliseconds: 20),
          ),
          failure(ExpansionTransportFailure.timeout),
        );
        pending.complete(lateSocket);
        await Future<void>.delayed(Duration.zero);
        expect(cancellations, greaterThan(0));
        expect(lateSocket.destroyed, isTrue);
        if (tls) expect(raw.destroyed, isTrue);
      },
    );
  }

  test(
    'separate requests do not reuse server cookies or authentication',
    () async {
      var requests = 0;
      final server = await localServer((r) {
        requests++;
        expect(r.headers.value('cookie'), isNull);
        expect(r.headers.value('authorization'), isNull);
        r.response.cookies.add(Cookie('session', 'must-not-return'));
        r.response.statusCode = requests == 1 ? 401 : 200;
        r.response.headers.set('www-authenticate', 'Basic realm="test"');
        r.response.close();
      });
      final session = NativeExpansionHttpSession(
        resolver: publicDns,
        connector: (_, _) => localConnect(server),
      );
      addTearDown(session.close);
      for (var i = 0; i < 2; i++) {
        await (await session.send('HEAD', _url)).close();
      }
      expect(requests, 2);
    },
  );

  for (final mode in ['untrusted', 'trusted', 'wrong-host']) {
    final trusted = mode != 'untrusted';
    test('real local TLS $mode', () async {
      final serverContext = SecurityContext()
        ..useCertificateChain('${_fixture}_cert.pem')
        ..usePrivateKey('${_fixture}_key.pem');
      final server = await HttpServer.bindSecure(
        InternetAddress.loopbackIPv4,
        0,
        serverContext,
      );
      final hosts = <String?>[];
      server.listen((r) {
        hosts.add(r.headers.value('host'));
        r.response.close();
      }, onError: (Object _) {});
      addTearDown(() => server.close(force: true));
      final testContext = SecurityContext()
        ..setTrustedCertificates('${_fixture}_cert.pem');
      final session = NativeExpansionHttpSession(
        resolver: publicDns,
        connector: (_, _) =>
            Socket.startConnect(InternetAddress.loopbackIPv4, server.port),
        tlsUpgrader: trusted
            ? (socket, {required hostname, required onBadCertificate}) =>
                  SecureSocket.secure(
                    socket,
                    host: hostname,
                    context: testContext,
                    onBadCertificate: onBadCertificate,
                  )
            : null,
      );
      addTearDown(session.close);
      if (mode == 'trusted') {
        final response = await session.send('HEAD', 'https://$_hostname');
        expect(response.statusCode, 200);
        expect(hosts, [_hostname]);
        await response.close();
      } else {
        await expectLater(
          session.send(
            'HEAD',
            'https://${mode == 'wrong-host' ? 'wrong.scamlens.net' : _hostname}',
          ),
          failure(ExpansionTransportFailure.tls),
        );
        expect(hosts, isEmpty);
      }
    });
  }
}

// Parses only the controlled test ClientHello, not a production TLS parser.
String _clientHelloSni(List<int> bytes) {
  int word(int offset) => bytes[offset] << 8 | bytes[offset + 1];
  var offset = 5 + 4 + 2 + 32; // record, handshake, version, random
  offset += 1 + bytes[offset]; // session ID
  offset += 2 + word(offset); // cipher suites
  offset += 1 + bytes[offset]; // compression methods
  final end = offset + 2 + word(offset);
  offset += 2;
  while (offset < end) {
    final type = word(offset);
    final length = word(offset + 2);
    offset += 4;
    if (type == 0) {
      final nameLength = word(offset + 3);
      return ascii.decode(bytes.sublist(offset + 5, offset + 5 + nameLength));
    }
    offset += length;
  }
  throw StateError('ClientHello contained no SNI');
}

class _SocketDouble implements Socket {
  bool destroyed = false;
  @override
  void destroy() => destroyed = true;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _CertificateDouble implements X509Certificate {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
