import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:scamlens/features/scanner/ui/bloc/scanner_bloc.dart';
import 'package:scamlens/features/smishing/domain/entities/sms_analysis_result.dart';
import 'package:scamlens/features/smishing/domain/usecases/analyze_sms_usecase.dart';
import 'package:scamlens/features/smishing/ui/bloc/smishing_bloc.dart';
import 'package:scamlens/shared/analysis_progress/domain/analysis_progress.dart';
import 'package:scamlens/shared/url_processing/domain/entities/url_expansion_result.dart';
import 'package:scamlens/shared/url_processing/domain/entities/url_processing_result.dart';
import 'package:scamlens/shared/url_processing/domain/services/url_normalizer.dart';
import 'package:scamlens/shared/url_processing/domain/usecases/process_url_usecase.dart';
import 'package:scamlens/shared/url_processing/data/services/http_url_expander.dart';
import 'package:scamlens/shared/url_processing/data/transport/expansion_http_session_stub.dart';
import 'package:scamlens/shared/url_risk/domain/entities/risk_evaluation_result.dart';
import 'package:scamlens/shared/url_risk/domain/usecases/evaluate_url_risk_usecase.dart';

import 'risk_fixture.dart';

Future<void> flush() => Future<void>.delayed(Duration.zero);

class _ControlledSms implements AnalyzeSmsUseCase {
  final calls = <String>[];
  final callbacks = <String, AnalysisProgressCallback>{};
  final pending = <String, Completer<SmsAnalysisResult>>{};
  @override
  Future<SmsAnalysisResult> call(
    String text, {
    AnalysisProgressCallback? onProgress,
  }) {
    calls.add(text);
    callbacks[text] = onProgress!;
    onProgress(
      const AnalysisProgress(
        AnalysisStage.extractLinks,
        AnalysisStageStatus.active,
      ),
    );
    return pending
        .putIfAbsent(text, () => Completer<SmsAnalysisResult>())
        .future;
  }

  @override
  Never get extractor => throw UnimplementedError();
  @override
  Never get processUrlUseCase => throw UnimplementedError();
}

class _ControlledProcessor extends ProcessUrlUseCase {
  final calls = <String>[];
  final callbacks = <String, AnalysisProgressCallback>{};
  final pending = <String, Completer<UrlProcessingResult>>{};
  _ControlledProcessor()
    : super(normalizer: UrlNormalizer(), expander: TestExpander());
  @override
  Future<UrlProcessingResult> call(
    String text, {
    AnalysisProgressCallback? onProgress,
  }) {
    calls.add(text);
    callbacks[text] = onProgress!;
    onProgress(
      const AnalysisProgress(
        AnalysisStage.normalizeUrl,
        AnalysisStageStatus.active,
      ),
    );
    return pending
        .putIfAbsent(text, () => Completer<UrlProcessingResult>())
        .future;
  }
}

UrlProcessingResult processed(String text) => UrlProcessingResult(
  contentRaw: text,
  normalizedUrl: text,
  isUrl: true,
  wasShortened: false,
  expansion: UrlExpansionResult(status: UrlExpansionStatus.notAttempted),
);

void main() {
  test(
    'ordinary QR emits actual normalize/brand/risk/preparation, no expansion',
    () async {
      final fixture = RiskFixture();
      final bloc = ScannerBloc(
        processUrlUseCase: fixture.processor,
        evaluateUrlRiskUseCase: fixture.evaluator,
      );
      addTearDown(bloc.close);
      final pending = bloc.stream.firstWhere((s) => s is ScannerSuccessState);
      bloc.add(QRCodeScannedEvent(rawValue: 'https://bancolombia.com'));
      final state = await pending as ScannerSuccessState;
      expect(state.progress.stages.map((e) => e.stage), [
        AnalysisStage.normalizeUrl,
        AnalysisStage.brandCheck,
        AnalysisStage.evaluateRisk,
        AnalysisStage.prepareResult,
      ]);
      expect(
        state.progress.stages.map((e) => e.status),
        everyElement(AnalysisStageStatus.completed),
      );
      expect(state.riskEvaluation.level, RiskLevel.green);
      expect(fixture.processor.calls, 1);
      expect(fixture.catalog.calls, 1);
    },
  );

  test(
    'shortener reports expansion started and completed exactly once',
    () async {
      final fixture = RiskFixture();
      fixture.expander.result = UrlExpansionResult(
        status: UrlExpansionStatus.resolved,
        redirectCount: 1,
        verifiedDestination: 'https://bancolombia.com/',
        lastHttpStatus: 200,
      );
      final events = <AnalysisProgress>[];
      final result = await fixture.processor(
        'https://bit.ly/a',
        onProgress: events.add,
      );
      expect(
        events
            .where((e) => e.stage == AnalysisStage.expandShortener)
            .map((e) => e.status),
        [AnalysisStageStatus.active, AnalysisStageStatus.completed],
      );
      expect(result.expansion!.verifiedDestination, 'https://bancolombia.com/');
      expect(fixture.expander.calls, 1);
    },
  );

  test(
    'browser transport unsupported is unavailable, never completed',
    () async {
      final events = <AnalysisProgress>[];
      final processor = ProcessUrlUseCase(
        normalizer: UrlNormalizer(),
        expander: HttpUrlExpander(
          sessionFactory: () => UnsupportedExpansionHttpSession(),
        ),
      );
      final result = await processor(
        'https://bit.ly/a',
        onProgress: events.add,
      );
      final expansion = events
          .where((e) => e.stage == AnalysisStage.expandShortener)
          .toList();
      expect(expansion.last.status, AnalysisStageStatus.unavailable);
      expect(expansion.last.reason, AnalysisProgressReason.unsupportedPlatform);
      expect(
        expansion.any((e) => e.status == AnalysisStageStatus.completed),
        isFalse,
      );
      expect(result.expansion!.status, UrlExpansionStatus.unsupportedPlatform);
      expect(EvaluateUrlRiskUseCase()(result).level, RiskLevel.yellow);
    },
  );

  for (final (status, reason) in [
    (UrlExpansionStatus.failed, AnalysisProgressReason.error),
    (UrlExpansionStatus.blocked, AnalysisProgressReason.blocked),
    (UrlExpansionStatus.timeout, AnalysisProgressReason.timeout),
  ]) {
    test('expansion $status emits failure and preserves uncertainty', () async {
      final fixture = RiskFixture();
      fixture.expander.result = UrlExpansionResult(
        status: status,
        failureReason: status == UrlExpansionStatus.timeout
            ? null
            : UrlExpansionFailureReason.connection,
      );
      final events = <AnalysisProgress>[];
      final result = await fixture.processor(
        'https://bit.ly/a',
        onProgress: events.add,
      );
      final expansion = events
          .where((e) => e.stage == AnalysisStage.expandShortener)
          .last;
      expect(expansion.status, AnalysisStageStatus.failed);
      expect(expansion.reason, reason);
      expect(fixture.evaluator(result).hasUncertainty, isTrue);
    });
  }

  for (final (text, total) in [
    ('Sin enlaces', 0),
    ('https://bancolombia.com', 1),
    (
      'https://bancolombia.com https://independent-shop.net https://bancolombia.com',
      2,
    ),
  ]) {
    test(
      'SMS unique count $total and no duplicated stages for repeated links',
      () async {
        final fixture = RiskFixture();
        final events = <AnalysisProgress>[];
        final result = await fixture.sms(text, onProgress: events.add);
        expect(events.first.stage, AnalysisStage.extractLinks);
        expect(events[1].status, AnalysisStageStatus.completed);
        expect(events[1].linkTotal, total);
        final starts = events.where(
          (e) =>
              e.stage == AnalysisStage.normalizeUrl &&
              e.status == AnalysisStageStatus.active,
        );
        expect(
          starts.map((e) => e.linkIndex),
          List.generate(total, (i) => i + 1),
        );
        expect(starts.map((e) => e.linkTotal), everyElement(total));
        expect(fixture.processor.calls, total);
        expect(fixture.evaluator.inputs.length, total);
        expect(events.last.stage, AnalysisStage.prepareResult);
        expect(events.last.status, AnalysisStageStatus.completed);
        if (total == 2) {
          expect(result.urls.length, 3);
          expect(result.riskEvaluations[0], same(result.riskEvaluations[2]));
        }
      },
    );
  }

  test('progress callback exceptions cannot change results', () async {
    final fixture = RiskFixture();
    final result = await fixture.sms(
      'https://bancolombia.com',
      onProgress: (_) => throw StateError('observer'),
    );
    expect(result.riskEvaluations.single.level, RiskLevel.green);
  });

  test(
    'SMS A-B-A replays shared progress and ignores stale emissions/results',
    () async {
      final source = _ControlledSms();
      final bloc = SmishingBloc(analyzeSmsUseCase: source);
      addTearDown(bloc.close);
      bloc.add(AnalyzeSmsEvent(text: 'A'));
      await flush();
      source.callbacks['A']!(
        const AnalysisProgress(
          AnalysisStage.normalizeUrl,
          AnalysisStageStatus.active,
          linkIndex: 1,
          linkTotal: 2,
        ),
      );
      bloc.add(AnalyzeSmsEvent(text: 'B'));
      await flush();
      final b = bloc.state;
      source.callbacks['A']!(
        const AnalysisProgress(
          AnalysisStage.brandCheck,
          AnalysisStageStatus.active,
          linkIndex: 1,
          linkTotal: 2,
        ),
      );
      expect(bloc.state, same(b));
      bloc.add(AnalyzeSmsEvent(text: 'A'));
      await flush();
      final replay = (bloc.state as SmishingLoading).progress;
      expect(replay.stages.last.stage, AnalysisStage.brandCheck);
      expect(source.calls, ['A', 'B']);
      final current = bloc.state;
      source.callbacks['B']!(
        const AnalysisProgress(
          AnalysisStage.prepareResult,
          AnalysisStageStatus.active,
        ),
      );
      expect(bloc.state, same(current));
      source.pending['B']!.complete(
        SmsAnalysisResult(originalText: 'B', urls: []),
      );
      await flush();
      expect(bloc.state, same(current));
      source.pending['A']!.complete(
        SmsAnalysisResult(originalText: 'A', urls: []),
      );
      await flush();
      expect((bloc.state as SmishingSuccess).result.originalText, 'A');
      final success = bloc.state;
      source.callbacks['A']!(
        const AnalysisProgress(
          AnalysisStage.brandCheck,
          AnalysisStageStatus.active,
        ),
      );
      expect(bloc.state, same(success));
    },
  );

  test(
    'QR reset starts new request and ignores old progress and completion',
    () async {
      final source = _ControlledProcessor();
      final bloc = ScannerBloc(processUrlUseCase: source);
      addTearDown(bloc.close);
      bloc.add(QRCodeScannedEvent(rawValue: 'https://first.net'));
      await flush();
      bloc.add(ResetScannerEvent());
      await flush();
      bloc.add(QRCodeScannedEvent(rawValue: 'https://second.net'));
      await flush();
      final current = bloc.state;
      source.callbacks['https://first.net']!(
        const AnalysisProgress(
          AnalysisStage.expandShortener,
          AnalysisStageStatus.active,
        ),
      );
      expect(bloc.state, same(current));
      source.pending['https://first.net']!.complete(
        processed('https://first.net'),
      );
      await flush();
      expect(bloc.state, same(current));
      source.pending['https://second.net']!.complete(
        processed('https://second.net'),
      );
      await flush();
      expect(
        (bloc.state as ScannerSuccessState).contentRaw,
        'https://second.net',
      );
    },
  );

  test('QR reset A-A reuses pending processing and its progress', () async {
    final source = _ControlledProcessor();
    final bloc = ScannerBloc(processUrlUseCase: source);
    addTearDown(bloc.close);
    bloc.add(QRCodeScannedEvent(rawValue: 'https://first.net'));
    await flush();
    bloc.add(ResetScannerEvent());
    await flush();
    bloc.add(QRCodeScannedEvent(rawValue: 'https://first.net'));
    await flush();
    expect(source.calls, ['https://first.net']);
    expect(
      (bloc.state as ScannerProcessingState).progress.stages.single.stage,
      AnalysisStage.normalizeUrl,
    );
    source.pending['https://first.net']!.complete(
      processed('https://first.net'),
    );
    await flush();
    expect(bloc.state, isA<ScannerSuccessState>());
  });

  test('closed SMS bloc ignores late progress and successful result', () async {
    final source = _ControlledSms();
    final bloc = SmishingBloc(analyzeSmsUseCase: source);
    final states = <SmishingState>[];
    final subscription = bloc.stream.listen(states.add);
    bloc.add(AnalyzeSmsEvent(text: 'A'));
    await flush();
    final count = states.length;
    final closing = bloc.close();
    source.callbacks['A']!(
      const AnalysisProgress(
        AnalysisStage.brandCheck,
        AnalysisStageStatus.active,
      ),
    );
    source.pending['A']!.complete(
      SmsAnalysisResult(originalText: 'A', urls: []),
    );
    await closing;
    await flush();
    expect(states.length, count);
    await subscription.cancel();
  });

  test('closed QR bloc ignores late progress and error', () async {
    final source = _ControlledProcessor();
    final bloc = ScannerBloc(processUrlUseCase: source);
    final states = <ScannerState>[];
    final subscription = bloc.stream.listen(states.add);
    bloc.add(QRCodeScannedEvent(rawValue: 'https://first.net'));
    await flush();
    final count = states.length;
    final closing = bloc.close();
    source.callbacks['https://first.net']!(
      const AnalysisProgress(
        AnalysisStage.brandCheck,
        AnalysisStageStatus.active,
      ),
    );
    source.pending['https://first.net']!.completeError(
      StateError('late failure'),
    );
    await closing;
    await flush();
    expect(states.length, count);
    await subscription.cancel();
  });
}
