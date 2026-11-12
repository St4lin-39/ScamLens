import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:scamlens/shared/url_processing/domain/entities/url_expansion_result.dart';
import 'package:scamlens/shared/url_processing/domain/services/url_expander.dart';
import 'package:scamlens/shared/url_processing/domain/services/url_normalizer.dart';
import 'package:scamlens/shared/url_processing/domain/usecases/process_url_usecase.dart';

class _Expander implements UrlExpander {
  final calls = <String>[];
  Future<UrlExpansionResult> Function(String) respond = (_) =>
      throw StateError('Unexpected expansion');

  @override
  Future<UrlExpansionResult> expandUrl(String url) {
    calls.add(url);
    return respond(url);
  }
}

UrlExpansionResult resolved(String url) => UrlExpansionResult(
  status: UrlExpansionStatus.resolved,
  redirectCount: 1,
  announcedDestination: url,
  verifiedDestination: url,
  lastHttpStatus: 200,
);

class _FailingNormalizer extends UrlNormalizer {
  final bool failDetection;

  _FailingNormalizer({this.failDetection = false});

  @override
  String normalizeUrl(String rawUrl) {
    if (!failDetection) throw StateError('Normalization failed');
    return super.normalizeUrl(rawUrl);
  }

  @override
  bool isShortenedUrl(String url) => throw StateError('Detection failed');
}

void main() {
  late _Expander expander;
  late ProcessUrlUseCase process;

  setUp(() {
    expander = _Expander();
    process = ProcessUrlUseCase(
      normalizer: UrlNormalizer(),
      expander: expander,
    );
  });

  final textCases = [
    'hello world',
    '1.2.3',
    'person@example.com',
    '192.168.1.1',
    '999.168.1.1/path',
    'mailto:person@example.com',
    'https://[invalid',
  ];
  for (final text in textCases) {
    test('preserves text without expansion: $text', () async {
      final result = await process('  $text  ');
      expect(result.contentRaw, '  $text  ');
      expect(result.normalizedUrl, text);
      expect(result.isUrl, isFalse);
      expect(result.wasShortened, isFalse);
      expect(expander.calls, isEmpty);
    });
  }

  final urlCases = {
    'example.com': 'https://example.com/',
    'sms.bellapiel.com.co/2BP5ZRvI': 'https://sms.bellapiel.com.co/2BP5ZRvI',
    'sms.bellapiel.com.co/Tbx5JpyP': 'https://sms.bellapiel.com.co/Tbx5JpyP',
    '192.168.1.1/path': 'https://192.168.1.1/path',
    'HtTp://EXAMPLE.COM/a': 'http://example.com/a',
    'http://example.com': 'http://example.com/',
    'https://EXAMPLE.COM/path?utm_source=x&id=1#end':
        'https://example.com/path?id=1#end',
    'www.example.com': 'https://www.example.com/',
    'WWW.EXAMPLE.COM': 'https://www.example.com/',
    'HTTPS://EXAMPLE.COM': 'https://example.com/',
    'https:relative': 'https://https:relative',
    'https://bit.ly.example.com/a': 'https://bit.ly.example.com/a',
    'https://notbit.ly/a': 'https://notbit.ly/a',
  };
  for (final entry in urlCases.entries) {
    test('classifies and normalizes without expansion: ${entry.key}', () async {
      final result = await process('  ${entry.key}  ');
      expect(result.contentRaw, '  ${entry.key}  ');
      expect(result.normalizedUrl, entry.value);
      expect(result.isUrl, isTrue);
      expect(result.wasShortened, isFalse);
      expect(expander.calls, isEmpty);
    });
  }

  for (final raw in ['https://bit.ly/a', 'https://sub.BIT.LY/a', 'bit.ly/a']) {
    test(
      'expands known shortener keeping normalized input separate: $raw',
      () async {
        expander.respond = (_) async =>
            resolved('https://destination.example/path?utm_source=x&id=2');
        final result = await process(' $raw ');
        expect(result.contentRaw, ' $raw ');
        expect(result.normalizedUrl, UrlNormalizer().normalizeUrl(raw));
        expect(
          result.expansion!.verifiedDestination,
          'https://destination.example/path?utm_source=x&id=2',
        );
        expect(result.isUrl, isTrue);
        expect(result.wasShortened, isTrue);
        expect(expander.calls, [raw.contains('://') ? raw : 'https://$raw']);
      },
    );
  }

  test('retains failed expansion announcement without confirming it', () async {
    expander.respond = (_) async => UrlExpansionResult(
      status: UrlExpansionStatus.failed,
      failureReason: UrlExpansionFailureReason.connection,
      redirectCount: 1,
      announcedDestination: 'https://bit.ly/reached?utm_source=x',
    );
    final result = await process('https://bit.ly/a');
    expect(result.normalizedUrl, 'https://bit.ly/a');
    expect(
      result.expansion!.announcedDestination,
      'https://bit.ly/reached?utm_source=x',
    );
    expect(result.expansion!.verifiedDestination, isNull);
    expect(result.wasShortened, isTrue);
  });

  for (final synchronous in [false, true]) {
    test(
      'unexpected expansion failure keeps normalized input and flag (sync=$synchronous)',
      () async {
        expander.respond = (_) {
          if (synchronous) throw StateError('Expansion failed');
          return Future.error(StateError('Expansion failed'));
        };
        final result = await process(' https://BIT.LY/a?utm_source=x ');
        expect(result.contentRaw, ' https://BIT.LY/a?utm_source=x ');
        expect(result.normalizedUrl, 'https://bit.ly/a');
        expect(result.expansion!.status, UrlExpansionStatus.failed);
        expect(result.isUrl, isTrue);
        expect(result.wasShortened, isTrue);
      },
    );
  }

  for (final failDetection in [false, true]) {
    test(
      'normalization/detection failure uses raw (detection=$failDetection)',
      () async {
        process = ProcessUrlUseCase(
          normalizer: _FailingNormalizer(failDetection: failDetection),
          expander: expander,
        );
        final result = await process(' https://BIT.LY/a?utm_source=x ');
        expect(result.normalizedUrl, 'https://BIT.LY/a?utm_source=x');
        expect(result.isUrl, isTrue);
        expect(result.wasShortened, isFalse);
        expect(expander.calls, isEmpty);
      },
    );
  }

  for (final empty in ['', ' \n\t ']) {
    test('rejects empty content: ${empty.length} characters', () async {
      await expectLater(process(empty), throwsArgumentError);
      expect(expander.calls, isEmpty);
    });
  }

  test('waits for typed expansion result', () async {
    final pending = Completer<UrlExpansionResult>();
    expander.respond = (_) => pending.future;
    var completed = false;
    final future = process('https://bit.ly/a').then((result) {
      completed = true;
      return result;
    });
    await Future<void>.delayed(Duration.zero);
    expect(completed, isFalse);
    pending.complete(resolved('https://destination.example/'));
    final result = await future;
    expect(result.normalizedUrl, 'https://bit.ly/a');
    expect(
      result.expansion!.verifiedDestination,
      'https://destination.example/',
    );
  });

  for (final lateError in [false, true]) {
    testWidgets(
      'has no second timeout after three seconds (error=$lateError)',
      (tester) async {
        final pending = Completer<UrlExpansionResult>();
        expander.respond = (_) => pending.future;
        var completionCount = 0;
        final future = process(' https://BIT.LY/a?utm_source=x ')
            .then((result) {
              completionCount++;
              return result;
            });
        await tester.pump(const Duration(milliseconds: 2999));
        expect(completionCount, 0);
        await tester.pump(const Duration(milliseconds: 1));
        expect(completionCount, 0);
        expect(pending.isCompleted, isFalse);
        if (lateError) {
          pending.completeError(StateError('Late failure'));
        } else {
          pending.complete(resolved('https://late.example/'));
        }
        await tester.pump();
        final result = await future;
        expect(result.contentRaw, ' https://BIT.LY/a?utm_source=x ');
        expect(
          result.expansion!.status,
          lateError ? UrlExpansionStatus.failed : UrlExpansionStatus.resolved,
        );
        expect(completionCount, 1);
        expect(result.normalizedUrl, 'https://bit.ly/a');
        expect(expander.calls, ['https://BIT.LY/a?utm_source=x']);
      },
    );
  }

  test(
    'request preserves repeated query parameters, order and original content',
    () async {
      const raw = ' HTTPS://BIT.LY/a?z=2&utm_source=x&id=1&id=2&a=%2F#part ';
      final expansion = resolved('https://destination.example/?b=2&b=1');
      expander.respond = (_) async => expansion;
      final result = await process(raw);
      expect(result.contentRaw, raw);
      expect(expander.calls, [raw.trim()]);
      expect(result.normalizedUrl, UrlNormalizer().normalizeUrl(raw));
      expect(result.expansion, same(expansion));
    },
  );

  for (final status in UrlExpansionStatus.values) {
    test('propagates $status without inferring success', () async {
      final expansion = status == UrlExpansionStatus.resolved
          ? resolved('https://destination.example/')
          : UrlExpansionResult(
              status: status,
              failureReason:
                  status == UrlExpansionStatus.failed ||
                      status == UrlExpansionStatus.blocked
                  ? UrlExpansionFailureReason.unknown
                  : null,
            );
      expander.respond = (_) async => expansion;
      final result = await process('https://bit.ly/a');
      expect(result.expansion, same(expansion));
      expect(result.normalizedUrl, 'https://bit.ly/a');
    });
  }
}
