import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:scamlens/shared/url_processing/domain/entities/url_expansion_result.dart';
import 'package:scamlens/features/smishing/domain/services/sms_url_extractor.dart';
import 'package:scamlens/features/smishing/domain/usecases/analyze_sms_usecase.dart';
import 'package:scamlens/shared/url_processing/domain/entities/url_processing_result.dart';
import 'package:scamlens/shared/url_processing/domain/services/url_expander.dart';
import 'package:scamlens/shared/url_processing/domain/services/url_normalizer.dart';
import 'package:scamlens/shared/url_processing/domain/usecases/process_url_usecase.dart';

class _ControlledExpander implements UrlExpander {
  final calls = <String>[];

  @override
  Future<UrlExpansionResult> expandUrl(String url) async {
    calls.add(url);
    return UrlExpansionResult(
      status: UrlExpansionStatus.resolved,
      redirectCount: 1,
      verifiedDestination:
          'https://destination.example/path?utm_source=sms&id=2',
      lastHttpStatus: 200,
    );
  }
}

class _ControlledProcessor extends ProcessUrlUseCase {
  final calls = <String>[];
  Future<UrlProcessingResult> Function(String)? respond;

  _ControlledProcessor()
    : super(normalizer: UrlNormalizer(), expander: _ControlledExpander());

  @override
  Future<UrlProcessingResult> call(String content) {
    calls.add(content);
    if (respond != null) return respond!(content);
    return super.call(content);
  }
}

void main() {
  late _ControlledProcessor processor;
  late AnalyzeSmsUseCase analyze;

  setUp(() {
    processor = _ControlledProcessor();
    analyze = AnalyzeSmsUseCase(
      extractor: SmsUrlExtractor(),
      processUrlUseCase: processor,
    );
  });

  for (final text in ['', '   ', '\t\n\r']) {
    test('rejects blank message of length ${text.length}', () async {
      await expectLater(analyze(text), throwsArgumentError);
      expect(processor.calls, isEmpty);
    });
  }

  test(
    'bare domain in a message is processed and original text is retained',
    () async {
      const text = '  Consulta example.com cuando quieras.  ';
      final result = await analyze(text);
      expect(result.originalText, text);
      expect(result.urls.single.normalizedUrl, 'https://example.com/');
      expect(processor.calls, ['example.com']);
    },
  );

  test('BELLA PIEL preserves both occurrences and normalizes through processor', () async {
    const text =
        'BELLA PIEL: ¿Manifestaste autocuidado? Hoy 11:11 hasta 30% Off en ISDIN sms.bellapiel.com.co/2BP5ZRvI WP sms.bellapiel.com.co/Tbx5JpyP hasta 12/11 T&C';
    final result = await analyze(text);
    expect(result.originalText, text);
    expect(processor.calls, [
      'sms.bellapiel.com.co/2BP5ZRvI',
      'sms.bellapiel.com.co/Tbx5JpyP',
    ]);
    expect(result.urls.map((url) => url.contentRaw), processor.calls);
    expect(result.urls.map((url) => url.normalizedUrl), [
      'https://sms.bellapiel.com.co/2BP5ZRvI',
      'https://sms.bellapiel.com.co/Tbx5JpyP',
    ]);
    expect(result.urls.every((url) => url.isUrl && !url.wasShortened), isTrue);
  });

  test('normalizes a URL using the existing processor', () async {
    final result = await analyze(
      'Mira https://EXAMPLE.COM/a?utm_source=x&id=1#end.',
    );
    expect(processor.calls, ['https://EXAMPLE.COM/a?utm_source=x&id=1#end']);
    expect(result.urls.single.contentRaw, processor.calls.single);
    expect(result.urls.single.normalizedUrl, 'https://example.com/a?id=1#end');
    expect(result.urls.single.isUrl, isTrue);
  });

  test(
    'retains order and all duplicates, processing each exact URL once',
    () async {
      const a = 'https://a.example/a';
      const b = 'www.b.example/b';
      final result = await analyze('$a\n$b, $a $b $a');
      expect(processor.calls, [a, b]);
      expect(result.urls.map((url) => url.contentRaw), [a, b, a, b, a]);
      expect(identical(result.urls[0], result.urls[2]), isTrue);
      expect(identical(result.urls[1], result.urls[3]), isTrue);
    },
  );

  test('does not deduplicate different raw spellings', () async {
    await analyze('https://EXAMPLE.COM https://example.com');
    expect(processor.calls, ['https://EXAMPLE.COM', 'https://example.com']);
  });

  test(
    'uses actual expansion flow with a controlled Domain expander',
    () async {
      final expander = _ControlledExpander();
      final usecase = AnalyzeSmsUseCase(
        extractor: SmsUrlExtractor(),
        processUrlUseCase: ProcessUrlUseCase(
          normalizer: UrlNormalizer(),
          expander: expander,
        ),
      );
      final result = await usecase('https://bit.ly/a https://bit.ly/a');
      expect(expander.calls, ['https://bit.ly/a']);
      expect(result.urls, hasLength(2));
      expect(result.urls.first.normalizedUrl, 'https://bit.ly/a');
      expect(result.urls.first.wasShortened, isTrue);
      expect(result.urls.first.expansion!.status, UrlExpansionStatus.resolved);
      expect(
        result.urls.first.expansion!.verifiedDestination,
        'https://destination.example/path?utm_source=sms&id=2',
      );
    },
  );

  test('bare shortener uses only the existing expansion flow', () async {
    final expander = _ControlledExpander();
    final usecase = AnalyzeSmsUseCase(
      extractor: SmsUrlExtractor(),
      processUrlUseCase: ProcessUrlUseCase(
        normalizer: UrlNormalizer(),
        expander: expander,
      ),
    );
    final result = await usecase('bit.ly/a bit.ly/a');
    expect(expander.calls, ['https://bit.ly/a']);
    expect(result.urls, hasLength(2));
    expect(result.urls.every((url) => url.isUrl && url.wasShortened), isTrue);
    expect(result.urls.first.normalizedUrl, 'https://bit.ly/a');
  });

  for (final synchronous in [true, false]) {
    test(
      'unexpected failure preserves original and continues (sync=$synchronous)',
      () async {
        processor.respond = (url) {
          if (url == 'https://bit.ly/fail') {
            if (synchronous) throw StateError('Unexpected failure');
            return Future.error(StateError('Unexpected failure'));
          }
          return Future.value(
            UrlProcessingResult(
              contentRaw: url,
              normalizedUrl: '$url/',
              isUrl: true,
              wasShortened: false,
            ),
          );
        };
        final result = await analyze(
          'https://a.example https://bit.ly/fail https://b.example https://bit.ly/fail',
        );
        expect(processor.calls, [
          'https://a.example',
          'https://bit.ly/fail',
          'https://b.example',
        ]);
        expect(result.urls.map((url) => url.contentRaw), [
          'https://a.example',
          'https://bit.ly/fail',
          'https://b.example',
          'https://bit.ly/fail',
        ]);
        expect(result.urls[1].normalizedUrl, 'https://bit.ly/fail');
        expect(result.urls[1].wasShortened, isFalse);
        expect(identical(result.urls[1], result.urls[3]), isTrue);
        expect(result.urls[2].normalizedUrl, 'https://b.example/');
      },
    );
  }

  test('waits for each distinct URL before starting the next', () async {
    final pending = Completer<UrlProcessingResult>();
    processor.respond = (url) => pending.future;
    final future = analyze('https://a.example https://b.example');
    await Future<void>.delayed(Duration.zero);
    expect(processor.calls, ['https://a.example']);
    pending.complete(
      const UrlProcessingResult(
        contentRaw: 'https://a.example',
        normalizedUrl: 'https://a.example/',
        isUrl: true,
        wasShortened: false,
      ),
    );
    await future;
    expect(processor.calls, ['https://a.example', 'https://b.example']);
  });

  test('cache is scoped to each message analysis', () async {
    await analyze('https://example.com');
    await analyze('https://example.com');
    expect(processor.calls, ['https://example.com', 'https://example.com']);
  });
}
