import 'dart:async';

import 'package:scamlens/shared/analysis_progress/domain/analysis_progress.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:scamlens/shared/url_processing/domain/entities/url_expansion_result.dart';
import 'package:scamlens/features/smishing/domain/entities/sms_analysis_result.dart';
import 'package:scamlens/features/smishing/domain/usecases/analyze_sms_usecase.dart';
import 'package:scamlens/features/smishing/ui/bloc/smishing_bloc.dart';
import 'package:scamlens/shared/url_processing/domain/entities/url_processing_result.dart';

class _AnalyzeSmsDouble implements AnalyzeSmsUseCase {
  final calls = <String>[];
  Future<SmsAnalysisResult> Function(String) respond = (text) async {
    if (text.trim().isEmpty) throw ArgumentError.value(text, 'text');
    return SmsAnalysisResult(originalText: text, urls: []);
  };

  @override
  Future<SmsAnalysisResult> call(
    String text, {
    AnalysisProgressCallback? onProgress,
  }) {
    calls.add(text);
    return respond(text);
  }

  // Constructor collaborators are intentionally never used by this double.
  @override
  Never get extractor => throw UnsupportedError('Unused');

  @override
  Never get processUrlUseCase => throw UnsupportedError('Unused');
}

Future<void> _flush() => Future<void>.delayed(Duration.zero);

SmsAnalysisResult _result(String text) =>
    SmsAnalysisResult(originalText: text, urls: []);

void main() {
  late _AnalyzeSmsDouble useCase;
  late SmishingBloc bloc;
  late List<SmishingState> states;
  late StreamSubscription<SmishingState> subscription;

  setUp(() {
    useCase = _AnalyzeSmsDouble();
    bloc = SmishingBloc(analyzeSmsUseCase: useCase);
    states = [];
    subscription = bloc.stream.listen(states.add);
  });

  tearDown(() async {
    await bloc.close();
    await subscription.cancel();
  });

  Future<SmishingState> analyze(String text) {
    final terminal = bloc.stream.firstWhere(
      (s) => s is SmishingSuccess || s is SmishingError,
    );
    bloc.add(AnalyzeSmsEvent(text: text));
    return terminal;
  }

  Future<void> reset() async {
    final initial = bloc.stream.firstWhere((s) => s is SmishingInitial);
    bloc.add(ResetSmishingEvent());
    await initial;
  }

  test('starts initial with only the injected Domain use case', () {
    expect(bloc.state, isA<SmishingInitial>());
    expect(bloc.analyzeSmsUseCase, same(useCase));
    expect(useCase.calls, isEmpty);
  });

  test(
    'emits loading then success and preserves the complete result identity',
    () async {
      final expansion = UrlExpansionResult(
        status: UrlExpansionStatus.timeout,
        redirectCount: 1,
        announcedDestination: 'https://destination.example/',
        lastHttpStatus: 302,
      );
      final url = UrlProcessingResult(
        contentRaw: 'https://bit.ly/a',
        normalizedUrl: 'https://bit.ly/a',
        isUrl: true,
        wasShortened: true,
        expansion: expansion,
      );
      final result = SmsAnalysisResult(
        originalText: '  SMS  ',
        urls: [url, url],
      );
      useCase.respond = (_) async => result;
      final success = await analyze('  SMS  ') as SmishingSuccess;
      expect(states, [isA<SmishingLoading>(), isA<SmishingSuccess>()]);
      expect(success.result, same(result));
      expect(success.result.urls, same(result.urls));
      expect(success.result.urls.first.expansion, same(expansion));
      expect(success.result.urls.first.expansion!.verifiedDestination, isNull);
      expect(useCase.calls, ['  SMS  ']);
    },
  );

  test('zero URLs is a successful analysis', () async {
    final success = await analyze('Mensaje sin enlaces') as SmishingSuccess;
    expect(success.result.urls, isEmpty);
    expect(success.result.originalText, 'Mensaje sin enlaces');
  });

  for (final text in ['', '   ', '\t\n']) {
    test('validation error for blank text of length ${text.length}', () async {
      final error = await analyze(text) as SmishingError;
      expect(states, [isA<SmishingLoading>(), isA<SmishingError>()]);
      expect(error.errorMessage, 'Enter an SMS message to analyze.');
      expect(useCase.calls, [text]);
    });
  }

  for (final synchronous in [true, false]) {
    test(
      'unexpected exception becomes a readable error (sync=$synchronous)',
      () async {
        useCase.respond = (_) {
          if (synchronous) throw StateError('internal detail');
          return Future.error(StateError('internal detail'));
        };
        final error = await analyze('SMS') as SmishingError;
        expect(states, [isA<SmishingLoading>(), isA<SmishingError>()]);
        expect(
          error.errorMessage,
          'Could not analyze the SMS. Please try again.',
        );
      },
    );
  }

  test('reset returns to initial after success', () async {
    await analyze('SMS');
    await reset();
    expect(bloc.state, isA<SmishingInitial>());
  });

  for (final fail in [false, true]) {
    test('late completion after reset is ignored (failure=$fail)', () async {
      final pending = Completer<SmsAnalysisResult>();
      useCase.respond = (_) => pending.future;
      bloc.add(AnalyzeSmsEvent(text: 'A'));
      await _flush();
      await reset();
      final initial = bloc.state;
      if (fail) {
        pending.completeError(StateError('late'));
      } else {
        pending.complete(_result('A'));
      }
      await _flush();
      expect(bloc.state, same(initial));
      expect(states, [isA<SmishingLoading>(), isA<SmishingInitial>()]);
    });
  }

  for (final failOld in [false, true]) {
    test('only newest request publishes (old failure=$failOld)', () async {
      final old = Completer<SmsAnalysisResult>();
      final latest = Completer<SmsAnalysisResult>();
      useCase.respond = (text) => text == 'A' ? old.future : latest.future;
      bloc.add(AnalyzeSmsEvent(text: 'A'));
      await _flush();
      bloc.add(AnalyzeSmsEvent(text: 'B'));
      await _flush();
      final result = _result('B');
      latest.complete(result);
      await _flush();
      final success = bloc.state as SmishingSuccess;
      expect(success.result, same(result));
      if (failOld) {
        old.completeError(StateError('obsolete'));
      } else {
        old.complete(_result('A'));
      }
      await _flush();
      expect(bloc.state, same(success));
      expect(states, [
        isA<SmishingLoading>(),
        isA<SmishingLoading>(),
        isA<SmishingSuccess>(),
      ]);
    });
  }

  test('old completion cannot replace loading of the latest request', () async {
    final old = Completer<SmsAnalysisResult>();
    final latest = Completer<SmsAnalysisResult>();
    useCase.respond = (text) => text == 'A' ? old.future : latest.future;
    bloc.add(AnalyzeSmsEvent(text: 'A'));
    await _flush();
    bloc.add(AnalyzeSmsEvent(text: 'B'));
    await _flush();
    old.complete(_result('A'));
    await _flush();
    expect(bloc.state, isA<SmishingLoading>());
    latest.complete(_result('B'));
    await _flush();
    expect((bloc.state as SmishingSuccess).result.originalText, 'B');
  });

  test('duplicate pending request does not process or emit twice', () async {
    final pending = Completer<SmsAnalysisResult>();
    useCase.respond = (_) => pending.future;
    bloc.add(AnalyzeSmsEvent(text: 'A'));
    bloc.add(AnalyzeSmsEvent(text: 'A'));
    await _flush();
    expect(useCase.calls, ['A']);
    expect(states, [isA<SmishingLoading>()]);
    pending.complete(_result('A'));
    await _flush();
    expect(states, [isA<SmishingLoading>(), isA<SmishingSuccess>()]);
  });

  test('completed text can be analyzed again', () async {
    await analyze('A');
    await analyze('A');
    expect(useCase.calls, ['A', 'A']);
  });

  for (final withReset in [false, true]) {
    test(
      'reuses pending A after ${withReset ? 'reset' : 'B'} and publishes latest A',
      () async {
        final a = Completer<SmsAnalysisResult>();
        final b = Completer<SmsAnalysisResult>();
        useCase.respond = (text) => text == 'A' ? a.future : b.future;
        bloc.add(AnalyzeSmsEvent(text: 'A'));
        await _flush();
        if (withReset) {
          await reset();
        } else {
          bloc.add(AnalyzeSmsEvent(text: 'B'));
          await _flush();
        }
        bloc.add(AnalyzeSmsEvent(text: 'A'));
        await _flush();
        expect(useCase.calls, withReset ? ['A'] : ['A', 'B']);
        final result = _result('A');
        a.complete(result);
        await _flush();
        expect((bloc.state as SmishingSuccess).result, same(result));
        final success = bloc.state;
        b.complete(_result('B'));
        await _flush();
        expect(bloc.state, same(success));
      },
    );
  }
}
