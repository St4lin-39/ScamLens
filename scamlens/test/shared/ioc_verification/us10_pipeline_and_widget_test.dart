import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scamlens/components/ioc_threat_banner.dart';
import 'package:scamlens/components/risk_traffic_light.dart';
import 'package:scamlens/shared/analysis_progress/domain/analysis_progress.dart';
import 'package:scamlens/shared/ioc_verification/domain/entities/indicator_of_compromise.dart';
import 'package:scamlens/shared/ioc_verification/domain/entities/ioc_check_result.dart';
import 'package:scamlens/shared/ioc_verification/domain/repositories/ioc_repository.dart';
import 'package:scamlens/shared/ioc_verification/domain/usecases/verify_ioc_usecase.dart';
import 'package:scamlens/shared/url_processing/domain/entities/url_expansion_result.dart';
import 'package:scamlens/shared/url_processing/domain/services/url_expander.dart';
import 'package:scamlens/shared/url_processing/domain/services/url_normalizer.dart';
import 'package:scamlens/shared/url_processing/domain/usecases/process_url_usecase.dart';
import 'package:scamlens/shared/url_risk/domain/entities/risk_evaluation_result.dart';
import 'package:scamlens/shared/url_risk/domain/entities/risk_evidence.dart';
import 'package:scamlens/shared/url_risk/domain/usecases/evaluate_url_risk_usecase.dart';
import 'package:scamlens/theme/app_theme.dart';

class _FakeIocRepo implements IocRepository {
  final Future<IocCheckResult> Function(IocCandidateSet) handler;
  _FakeIocRepo(this.handler);

  @override
  Future<IocCheckResult> checkCandidates(IocCandidateSet candidates) =>
      handler(candidates);

  @override
  void invalidateCache() {}
}

class _StubExpander implements UrlExpander {
  final UrlExpansionResult expansion;
  _StubExpander(this.expansion);

  @override
  Future<UrlExpansionResult> expandUrl(String url) async => expansion;
}

void main() {
  test('confirmed IOC escalates non-impersonating domain and unresolved shortener to Red and blocks opening', () async {
    final maliciousIoc = IndicatorOfCompromise(
      id: 'ioc-1',
      type: IocType.url,
      value: 'https://bit.ly/known-scam',
      attackType: 'SMISHING',
      detectionSource: 'COMMUNITY_VERIFIED',
      active: true,
      createdIn: DateTime.utc(2026, 11, 26),
    );

    final stages = <AnalysisStage>[];
    final process = ProcessUrlUseCase(
      normalizer: UrlNormalizer(),
      expander: _StubExpander(
        UrlExpansionResult(status: UrlExpansionStatus.timeout),
      ),
      verifyIocUseCase: VerifyIocUseCase(
        repository: _FakeIocRepo((candidates) async {
          if (candidates.urls.contains('https://bit.ly/known-scam')) {
            return IocCheckResult(
              status: IocCheckStatus.matched,
              sourceAvailability: IocSourceAvailability.available,
              matchedIoc: maliciousIoc,
              matchedCandidate: 'https://bit.ly/known-scam',
            );
          }
          return const IocCheckResult(
            status: IocCheckStatus.clean,
            sourceAvailability: IocSourceAvailability.available,
          );
        }),
      ),
    );

    final processed = await process(
      'https://bit.ly/known-scam',
      onProgress: (e) {
        if (e.status == AnalysisStageStatus.completed) stages.add(e.stage);
      },
    );
    expect(stages, contains(AnalysisStage.iocCheck));
    expect(processed.iocCheck?.isConfirmedThreat, isTrue);

    final evaluate = EvaluateUrlRiskUseCase();
    final risk = evaluate(processed);

    expect(risk.level, RiskLevel.red);
    expect(risk.hasConfirmedIoc, isTrue);
    expect(
      risk.evidences.map((e) => e.id),
      contains(RiskEvidenceId.confirmedIoc),
    );
  });

  testWidgets('IocThreatBanner and RiskTrafficLight render confirmed IOC block and prevent URL launch', (tester) async {
    final ioc = IndicatorOfCompromise(
      id: 'gsb-1',
      type: IocType.url,
      value: 'https://testsafebrowsing.appspot.com/s/phishing.html',
      attackType: 'PHISHING (SOCIAL_ENGINEERING)',
      detectionSource: 'GOOGLE_SAFE_BROWSING',
      active: true,
      createdIn: DateTime.utc(2026, 11, 26),
    );

    final iocResult = IocCheckResult(
      status: IocCheckStatus.matched,
      sourceAvailability: IocSourceAvailability.available,
      matchedIoc: ioc,
      matchedCandidate: ioc.value,
      heuristicDetail: const IocHeuristicDetail(
        ruleName: 'CONFIRMED_IOC_MATCH',
        result: 'CONFIRMED_THREAT',
        assignedRiskWeight: 100,
        technicalEvidence:
            'Matched confirmed URL indicator classified as PHISHING.',
      ),
    );

    final risk = RiskEvaluationResult(
      level: RiskLevel.red,
      evidences: [
        RiskEvidence(
          id: RiskEvidenceId.confirmedIoc,
          severity: EvidenceSeverity.high,
          justification:
              'Matched confirmed URL indicator classified as PHISHING.',
          subject: ioc.value,
        ),
      ],
      completeness: RiskAnalysisCompleteness.complete,
      uncertaintyReasons: const [],
      evaluatedUrl: ioc.value,
    );

    var launched = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                IocThreatBanner(iocCheck: iocResult),
                RiskTrafficLight(
                  evaluation: risk,
                  onOpenUrl: (_) => launched = true,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('CONFIRMED THREAT BLOCKED (IOC)'), findsOneWidget);
    expect(find.text('GOOGLE_SAFE_BROWSING'), findsOneWidget);
    expect(find.text('Red · Confirmed malicious threat'), findsOneWidget);
    expect(
      find.text(
        'Direct opening blocked: matched a confirmed indicator of compromise (IOC).',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Open link'));
    expect(launched, isFalse);
  });
}
