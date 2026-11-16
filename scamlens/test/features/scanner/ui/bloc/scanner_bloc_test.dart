import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:scamlens/shared/url_processing/domain/entities/url_expansion_result.dart';
import 'package:scamlens/shared/url_processing/domain/services/url_normalizer.dart';
import 'package:scamlens/shared/url_processing/domain/services/url_expander.dart';
import 'package:scamlens/shared/url_processing/domain/usecases/process_url_usecase.dart';
import 'package:scamlens/features/scanner/ui/bloc/scanner_bloc.dart';

// No camera/permission events are sent: these tests exercise URL processing only.
class _UrlNormalizerDouble implements UrlNormalizer {
  final calls = <String>[];
  bool shortened = false;
  bool failNormalization = false;
  Future<UrlExpansionResult> Function(String)? expand;

  @override
  String normalizeUrl(String rawUrl) {
    calls.add('normalize:$rawUrl');
    if (failNormalization) throw StateError('Simulated normalization failure');
    if (rawUrl == 'https://normalized.example/' ||
        rawUrl == 'https://destination.example/' ||
        rawUrl == 'https://late.example/') {
      return rawUrl;
    }
    return 'https://normalized.example/';
  }

  @override
  bool isShortenedUrl(String url) {
    calls.add('shortened:$url');
    return shortened;
  }
}

class _UrlExpanderDouble implements UrlExpander {
  final _UrlNormalizerDouble service;
  _UrlExpanderDouble(this.service);

  @override
  Future<UrlExpansionResult> expandUrl(String url) {
    service.calls.add('expand:$url');
    return service.expand?.call(url) ??
        Future.value(resolved('https://destination.example/'));
  }
}

UrlExpansionResult resolved(String url) => UrlExpansionResult(
  status: UrlExpansionStatus.resolved,
  redirectCount: 1,
  verifiedDestination: url,
  lastHttpStatus: 200,
);

void main() {
  late _UrlNormalizerDouble service;
  late ScannerBloc bloc;
  late List<ScannerState> states;
  late StreamSubscription<ScannerState> subscription;

  setUp(() {
    service = _UrlNormalizerDouble();
    bloc = ScannerBloc(
      processUrlUseCase: ProcessUrlUseCase(
        normalizer: service,
        expander: _UrlExpanderDouble(service),
      ),
    );
    states = [];
    subscription = bloc.stream.listen(states.add);
  });
  tearDown(() async {
    await bloc.close();
    await subscription.cancel();
  });

  test(
    'maps the real use case result after expanding a recognized shortener',
    () async {
      final expansion = resolved(
        'https://destination.example/path?utm_source=x&id=2',
      );
      service.expand = (_) async => expansion;
      final integratedBloc = ScannerBloc(
        processUrlUseCase: ProcessUrlUseCase(
          normalizer: UrlNormalizer(),
          expander: _UrlExpanderDouble(service),
        ),
      );
      addTearDown(integratedBloc.close);
      final resultFuture = integratedBloc.stream.firstWhere(
        (state) => state is ScannerSuccessState,
      );
      integratedBloc.add(QRCodeScannedEvent(rawValue: ' https://BIT.LY/a '));
      final result = await resultFuture as ScannerSuccessState;
      expect(result.contentRaw, 'https://BIT.LY/a');
      expect(result.normalizedUrl, 'https://bit.ly/a');
      expect(result.isUrl, isTrue);
      expect(result.wasShortened, isTrue);
      expect(result.result.expansion, same(expansion));
      expect(service.calls, ['expand:https://BIT.LY/a']);
    },
  );

  for (final raw in [
    'sms.bellapiel.com.co/2BP5ZRvI',
    'HTTPS://sms.bellapiel.com.co/2BP5ZRvI',
  ]) {
    test(
      'real processing normalizes scanner input $raw without expansion',
      () async {
        final integratedBloc = ScannerBloc(
          processUrlUseCase: ProcessUrlUseCase(
            normalizer: UrlNormalizer(),
            expander: _UrlExpanderDouble(service),
          ),
        );
        addTearDown(integratedBloc.close);
        final future = integratedBloc.stream.firstWhere(
          (state) => state is ScannerSuccessState,
        );
        integratedBloc.add(QRCodeScannedEvent(rawValue: raw));
        final result = await future as ScannerSuccessState;
        expect(result.contentRaw, raw);
        expect(result.normalizedUrl, 'https://sms.bellapiel.com.co/2BP5ZRvI');
        expect(result.isUrl, isTrue);
        expect(result.wasShortened, isFalse);
        expect(service.calls, isEmpty);
      },
    );
  }

  Future<ScannerState> scan(String raw) {
    final result = bloc.stream.firstWhere(
      (s) => s is ScannerSuccessState || s is ScannerErrorState,
    );
    bloc.add(QRCodeScannedEvent(rawValue: raw));
    return result;
  }

  final classifications = <String, bool>{
    'http://example.com': true,
    'https://example.com': true,
    'www.example.com': true,
    'WWW.EXAMPLE.COM': true,
    'HTTPS://EXAMPLE.COM': true,
    // Current classification does not require a host.
    'https:relative': true,
    'example.com': true,
    'hello world': false,
    'Consulta example.com ahora': false,
    'person@example.com': false,
    '1.2.3': false,
    'sms.bellapiel.com.co/2BP5ZRvI': true,
    'mailto:person@example.com': false,
  };
  for (final entry in classifications.entries) {
    test('classifies ${entry.key} as isUrl=${entry.value}', () async {
      expect(bloc.state, isA<ScannerInitialState>());
      final result = await scan('  ${entry.key}  ') as ScannerSuccessState;
      expect(states.last, isA<ScannerSuccessState>());
      expect(
        states.take(states.length - 1),
        everyElement(isA<ScannerProcessingState>()),
      );
      expect(result.contentRaw, entry.key);
      expect(result.isUrl, entry.value);
      expect(result.wasShortened, isFalse);
      expect(
        result.normalizedUrl,
        entry.value ? 'https://normalized.example/' : entry.key,
      );
      expect(
        service.calls,
        entry.value
            ? [
                'normalize:${entry.key}',
                'shortened:https://normalized.example/',
              ]
            : isEmpty,
      );
    });
  }

  test(
    'empty input emits processing then the existing error message',
    () async {
      final result = await scan(' \n ') as ScannerErrorState;
      expect(states, [isA<ScannerProcessingState>(), isA<ScannerErrorState>()]);
      expect(result.errorMessage, 'Código QR vacío o ilegible');
      expect(service.calls, isEmpty);
    },
  );

  test(
    'shortener expands and remains processing until the result arrives',
    () async {
      final pending = Completer<UrlExpansionResult>();
      service.shortened = true;
      service.expand = (_) => pending.future;
      final processing = bloc.stream.firstWhere(
        (s) => s is ScannerProcessingState,
      );
      final resultFuture = scan('https://bit.ly/a');
      await processing;
      expect(bloc.state, isA<ScannerProcessingState>());
      pending.complete(resolved('https://destination.example/'));
      final result = await resultFuture as ScannerSuccessState;
      expect(result.normalizedUrl, 'https://normalized.example/');
      expect(result.isUrl, isTrue);
      expect(result.wasShortened, isTrue);
      expect(service.calls, [
        'normalize:https://bit.ly/a',
        'shortened:https://normalized.example/',
        'expand:https://bit.ly/a',
      ]);
    },
  );

  test('normalization exception falls back to trimmed raw content', () async {
    service.failNormalization = true;
    final result = await scan(' https://example.com ') as ScannerSuccessState;
    expect(result.contentRaw, 'https://example.com');
    expect(result.normalizedUrl, result.contentRaw);
    expect(result.isUrl, isTrue);
    expect(result.wasShortened, isFalse);
    expect(service.calls, ['normalize:https://example.com']);
  });

  test(
    'expansion exception keeps normalized input and shortener flag',
    () async {
      service.shortened = true;
      service.expand = (_) => Future<UrlExpansionResult>.delayed(
        const Duration(milliseconds: 1),
        () => throw StateError('Simulated failure'),
      );
      final result = await scan(' https://bit.ly/a ') as ScannerSuccessState;
      expect(result.normalizedUrl, 'https://normalized.example/');
      expect(result.wasShortened, isTrue);
      expect(states.last, isA<ScannerSuccessState>());
      expect(
        states.take(states.length - 1),
        everyElement(isA<ScannerProcessingState>()),
      );
    },
  );

  test('typed timeout preserves normalized input and shortener flag', () async {
    service.shortened = true;
    service.expand = (_) async =>
        UrlExpansionResult(status: UrlExpansionStatus.timeout);
    final result = await scan('https://bit.ly/a') as ScannerSuccessState;
    expect(result.normalizedUrl, 'https://normalized.example/');
    expect(result.wasShortened, isTrue);
    await Future<void>.delayed(Duration.zero);
    expect(bloc.state, same(result));
    expect(states.last, isA<ScannerSuccessState>());
    expect(
      states.take(states.length - 1),
      everyElement(isA<ScannerProcessingState>()),
    );
  });

  test('duplicate events are ignored while processing and after success; reset allows another scan', () async {
    final pending = Completer<UrlExpansionResult>();
    service.shortened = true;
    service.expand = (_) => pending.future;
    final processing = bloc.stream.firstWhere(
      (s) => s is ScannerProcessingState,
    );
    final resultFuture = scan('https://bit.ly/a');
    await processing;
    bloc.add(QRCodeScannedEvent(rawValue: 'https://ignored.example/'));
    await Future<void>.delayed(Duration.zero);
    expect(service.calls.length, 3);
    pending.complete(resolved('https://destination.example/'));
    final result = await resultFuture;
    bloc.add(QRCodeScannedEvent(rawValue: 'ignored text'));
    await Future<void>.delayed(Duration.zero);
    expect(bloc.state, same(result));
    final active = bloc.stream.firstWhere((s) => s is ScannerActiveState);
    bloc.add(ResetScannerEvent());
    await active;
    final next = await scan('another text') as ScannerSuccessState;
    expect(next.contentRaw, 'another text');
    expect(next.isUrl, isFalse);
  });
}
