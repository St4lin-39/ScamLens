import 'package:flutter_test/flutter_test.dart';
import 'package:scamlens/shared/url_processing/data/transport/expansion_http_session.dart';
import 'package:scamlens/shared/url_processing/data/transport/expansion_http_session_factory.dart';
import 'package:scamlens/shared/url_processing/data/transport/expansion_http_session_stub.dart';

void main() {
  test('factory creates independent sessions', () {
    final first = createExpansionHttpSession();
    final second = createExpansionHttpSession();
    expect(identical(first, second), isFalse);
    first.close();
    second.close();
  });

  for (final method in ['HEAD', 'GET']) {
    test(
      'stub reports unsupported without a network dependency: $method',
      () async {
        final session = UnsupportedExpansionHttpSession();
        await expectLater(
          session.send(method, 'https://bit.ly/a'),
          throwsA(
            isA<ExpansionTransportException>().having(
              (e) => e.failure,
              'failure',
              ExpansionTransportFailure.unsupportedPlatform,
            ),
          ),
        );
        session.close();
        session.close();
        await expectLater(
          session.send(method, 'https://bit.ly/a'),
          throwsA(
            isA<ExpansionTransportException>().having(
              (e) => e.failure,
              'failure',
              ExpansionTransportFailure.cancelled,
            ),
          ),
        );
      },
    );
  }

  test('response abstraction supports an injected in-memory session', () async {
    final session = _MemorySession();
    final response = await session.send('GET', 'https://bit.ly/a');
    expect(response.statusCode, 302);
    expect(response.headers['location'], '/target');
    expect(await response.body.toList(), isEmpty);
    await response.close();
    expect(session.response.closed, isTrue);
    session.close();
  });
}

class _MemorySession implements ExpansionHttpSession {
  final response = _MemoryResponse();
  @override
  Future<ExpansionHttpResponse> send(
    String method,
    String url, {
    Duration timeout = const Duration(seconds: 4),
  }) async => response;
  @override
  void close() {}
}

class _MemoryResponse implements ExpansionHttpResponse {
  bool closed = false;
  @override
  int get statusCode => 302;
  @override
  Map<String, String> get headers => const {'location': '/target'};
  @override
  Stream<List<int>> get body => const Stream.empty();
  @override
  Future<void> close() async {
    closed = true;
  }
}
