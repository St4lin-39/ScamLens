import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:scamlens/shared/url_processing/domain/services/url_expander.dart';
import 'package:scamlens/shared/url_processing/domain/services/url_normalizer.dart';
import 'package:scamlens/shared/url_processing/domain/usecases/process_url_usecase.dart';

class _Expander implements UrlExpander {
  final calls = <String>[];
  Future<String> Function(String) respond = (_) =>
      throw StateError('Unexpected expansion');

  @override
  Future<String> expandUrl(String url) {
    calls.add(url);
    return respond(url);
  }
}

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
    'example.com',
    'mailto:person@example.com',
    'https://[invalid',
  ];
  for (final text in textCases) {
    test('preserves text without expansion: $text', () async {
      final result = await process('  $text  ');
      expect(result.contentRaw, text);
      expect(result.normalizedUrl, text);
      expect(result.isUrl, isFalse);
      expect(result.wasShortened, isFalse);
      expect(expander.calls, isEmpty);
    });
  }

  final urlCases = {
    'http://example.com': 'http://example.com/',
    'https://EXAMPLE.COM/path?utm_source=x&id=1#end':
        'https://example.com/path?id=1#end',
    'www.example.com': 'https://www.example.com/',
    'WWW.EXAMPLE.COM': 'https://www.example.com/',
    'HTTPS://EXAMPLE.COM': 'https://https//EXAMPLE.COM',
    'https:relative': 'https://https:relative',
    'https://bit.ly.example.com/a': 'https://bit.ly.example.com/a',
    'https://notbit.ly/a': 'https://notbit.ly/a',
  };
  for (final entry in urlCases.entries) {
    test('classifies and normalizes without expansion: ${entry.key}', () async {
      final result = await process('  ${entry.key}  ');
      expect(result.contentRaw, entry.key);
      expect(result.normalizedUrl, entry.value);
      expect(result.isUrl, isTrue);
      expect(result.wasShortened, isFalse);
      expect(expander.calls, isEmpty);
    });
  }

  for (final raw in ['https://bit.ly/a', 'https://sub.BIT.LY/a']) {
    test('expands known shortener and normalizes destination: $raw', () async {
      expander.respond = (_) async =>
          'https://DESTINATION.example/path?utm_source=x&id=2#end';
      final result = await process(' $raw ');
      expect(result.contentRaw, raw);
      expect(result.normalizedUrl, 'https://destination.example/path?id=2#end');
      expect(result.isUrl, isTrue);
      expect(result.wasShortened, isTrue);
      expect(expander.calls, [UrlNormalizer().normalizeUrl(raw)]);
    });
  }

  test('normalizes the last URL returned by a failed HTTP expansion', () async {
    expander.respond = (_) async => 'https://bit.ly/reached?utm_source=x';
    final result = await process('https://bit.ly/a');
    expect(result.normalizedUrl, 'https://bit.ly/reached');
    expect(result.wasShortened, isTrue);
  });

  for (final synchronous in [false, true]) {
    test(
      'expansion failure uses raw and retains flag (sync=$synchronous)',
      () async {
        expander.respond = (_) {
          if (synchronous) throw StateError('Expansion failed');
          return Future.error(StateError('Expansion failed'));
        };
        final result = await process(' https://BIT.LY/a?utm_source=x ');
        expect(result.contentRaw, 'https://BIT.LY/a?utm_source=x');
        expect(result.normalizedUrl, result.contentRaw);
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

  test('waits for expansion before three seconds', () async {
    final pending = Completer<String>();
    expander.respond = (_) => pending.future;
    var completed = false;
    final future = process('https://bit.ly/a').then((result) {
      completed = true;
      return result;
    });
    await Future<void>.delayed(Duration.zero);
    expect(completed, isFalse);
    pending.complete('https://destination.example');
    expect((await future).normalizedUrl, 'https://destination.example/');
  });

  for (final lateError in [false, true]) {
    testWidgets(
      'three-second timeout ignores late completion (error=$lateError)',
      (tester) async {
        final pending = Completer<String>();
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
        final result = await future;
        expect(result.contentRaw, 'https://BIT.LY/a?utm_source=x');
        expect(result.normalizedUrl, 'https://bit.ly/a');
        expect(result.isUrl, isTrue);
        expect(result.wasShortened, isTrue);
        expect(pending.isCompleted, isFalse);
        if (lateError) {
          pending.completeError(StateError('Late failure'));
        } else {
          pending.complete('https://late.example/');
        }
        await tester.pump();
        expect(completionCount, 1);
        expect(result.normalizedUrl, 'https://bit.ly/a');
        expect(expander.calls, ['https://bit.ly/a']);
      },
    );
  }
}
