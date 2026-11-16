import 'package:flutter_test/flutter_test.dart';
import 'package:scamlens/features/scanner/ui/bloc/scanner_bloc.dart';
import 'package:scamlens/features/smishing/domain/entities/sms_analysis_result.dart';
import 'package:scamlens/features/smishing/ui/bloc/smishing_bloc.dart';
import 'package:scamlens/shared/brand_impersonation/domain/entities/official_brand_catalog.dart';
import 'package:scamlens/shared/url_risk/domain/entities/risk_evaluation_result.dart';
import 'package:scamlens/shared/url_risk/domain/entities/risk_evidence.dart';

import 'risk_fixture.dart';

void main() {
  for (final (url, level, partial) in [
    ('https://bancolombia.com', RiskLevel.green, false),
    ('https://independent-shop.net', RiskLevel.yellow, false),
    ('https://bancol0mbia.com', RiskLevel.red, false),
    ('https://bit.ly/a', RiskLevel.yellow, true),
  ]) {
    test(
      'QR carries $level and original processing identity for $url',
      () async {
        final fixture = RiskFixture();
        final bloc = ScannerBloc(
          processUrlUseCase: fixture.processor,
          evaluateUrlRiskUseCase: fixture.evaluator,
        );
        addTearDown(bloc.close);
        final pending = bloc.stream.firstWhere((s) => s is ScannerSuccessState);
        bloc.add(QRCodeScannedEvent(rawValue: url));
        final state = await pending as ScannerSuccessState;
        expect(state.riskEvaluation.level, level);
        expect(state.riskEvaluation.hasUncertainty, partial);
        expect(fixture.processor.calls, 1);
        expect(fixture.evaluator.inputs.single, same(state.result));
        expect(fixture.catalog.calls, 1);
        expect(fixture.expander.calls, url.contains('bit.ly') ? 1 : 0);
      },
    );
  }

  test(
    'catalog failure remains typed uncertainty through ScannerBloc',
    () async {
      final fixture = RiskFixture();
      fixture.catalog.status = BrandCatalogStatus.unavailable;
      final bloc = ScannerBloc(
        processUrlUseCase: fixture.processor,
        evaluateUrlRiskUseCase: fixture.evaluator,
      );
      addTearDown(bloc.close);
      final pending = bloc.stream.firstWhere((s) => s is ScannerSuccessState);
      bloc.add(QRCodeScannedEvent(rawValue: 'https://bancolombia.com'));
      final state = await pending as ScannerSuccessState;
      expect(state.riskEvaluation.level, RiskLevel.yellow);
      expect(
        state.riskEvaluation.uncertaintyReasons,
        contains(RiskEvidenceId.catalogUnavailable),
      );
    },
  );

  test(
    'SMS retains separate green/yellow/red risks and deduplicates all work',
    () async {
      final fixture = RiskFixture();
      final bloc = SmishingBloc(analyzeSmsUseCase: fixture.sms);
      addTearDown(bloc.close);
      final pending = bloc.stream.firstWhere((s) => s is SmishingSuccess);
      bloc.add(
        AnalyzeSmsEvent(
          text:
              'https://bancolombia.com https://independent-shop.net '
              'https://bancol0mbia.com https://bancolombia.com',
        ),
      );
      final state = await pending as SmishingSuccess;
      expect(state.result.riskEvaluations.map((r) => r.level), [
        RiskLevel.green,
        RiskLevel.yellow,
        RiskLevel.red,
        RiskLevel.green,
      ]);
      expect(state.result.urls[0], same(state.result.urls[3]));
      expect(
        state.result.riskEvaluations[0],
        same(state.result.riskEvaluations[3]),
      );
      expect(fixture.processor.calls, 3);
      expect(
        fixture.evaluator.inputs,
        orderedEquals(state.result.urls.take(3)),
      );
      expect(fixture.catalog.calls, 3);
      expect(fixture.expander.calls, 0);
      expect(
        () => state.result.riskEvaluations.clear(),
        throwsUnsupportedError,
      );
    },
  );

  test(
    'SMS unresolved URL cannot inherit another URL official evaluation',
    () async {
      final fixture = RiskFixture();
      final bloc = SmishingBloc(analyzeSmsUseCase: fixture.sms);
      addTearDown(bloc.close);
      final pending = bloc.stream.firstWhere((s) => s is SmishingSuccess);
      bloc.add(
        AnalyzeSmsEvent(text: 'https://bancolombia.com https://bit.ly/a'),
      );
      final state = await pending as SmishingSuccess;
      expect(state.result.riskEvaluations.first.level, RiskLevel.green);
      final unresolved = state.result.riskEvaluations.last;
      expect(unresolved.level, RiskLevel.yellow);
      expect(unresolved.evaluatedUrl, isNull);
      expect(
        unresolved.uncertaintyReasons,
        contains(RiskEvidenceId.unresolvedShortener),
      );
      expect(fixture.expander.calls, 1);
    },
  );

  test(
    'legacy SMS results remain cautious and reject mismatched risk count',
    () async {
      final fixture = RiskFixture();
      final url = await fixture.processor('https://bancolombia.com');
      final legacy = SmsAnalysisResult(originalText: '', urls: [url]);
      expect(legacy.riskEvaluations.single.level, RiskLevel.yellow);
      expect(legacy.riskEvaluations.single.hasUncertainty, isTrue);
      expect(
        () => SmsAnalysisResult(
          originalText: '',
          urls: [url],
          riskEvaluations: [],
        ),
        throwsArgumentError,
      );
    },
  );
}
