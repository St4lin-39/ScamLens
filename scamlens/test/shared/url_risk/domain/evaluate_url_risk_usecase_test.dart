import 'package:flutter_test/flutter_test.dart';
import 'package:scamlens/shared/brand_impersonation/data/datasources/supabase_official_brand_datasource.dart';
import 'package:scamlens/shared/brand_impersonation/data/models/official_brand_model.dart';
import 'package:scamlens/shared/brand_impersonation/data/repositories/official_brand_repository_impl.dart';
import 'package:scamlens/shared/brand_impersonation/domain/entities/brand_impersonation_result.dart';
import 'package:scamlens/shared/brand_impersonation/domain/entities/official_brand_catalog.dart';
import 'package:scamlens/shared/brand_impersonation/domain/usecases/detect_brand_impersonation_usecase.dart';
import 'package:scamlens/shared/url_processing/domain/entities/url_expansion_result.dart';
import 'package:scamlens/shared/url_processing/domain/entities/url_processing_result.dart';
import 'package:scamlens/shared/url_processing/domain/services/url_expander.dart';
import 'package:scamlens/shared/url_processing/domain/services/url_normalizer.dart';
import 'package:scamlens/shared/url_processing/domain/usecases/process_url_usecase.dart';
import 'package:scamlens/shared/url_risk/domain/entities/risk_evaluation_result.dart';
import 'package:scamlens/shared/url_risk/domain/entities/risk_evidence.dart';
import 'package:scamlens/shared/url_risk/domain/usecases/evaluate_url_risk_usecase.dart';

class _Datasource implements SupabaseOfficialBrandDatasource {
  bool fail = false;
  bool empty = false;
  int calls = 0;

  @override
  Never get client => throw UnimplementedError();

  @override
  Future<List<OfficialBrandModel>> fetchActiveBrands() async {
    calls++;
    if (fail) throw StateError('offline');
    return empty
        ? []
        : [
            OfficialBrandModel.fromJson({
              'id': 'brand-1',
              'entity_name': 'Bancolombia',
              'official_domain': 'bancolombia.com',
              'category': 'Banca',
              'active': true,
              'created_in': '2026-11-12T00:00:00Z',
            }),
          ];
  }
}

class _Expander implements UrlExpander {
  UrlExpansionResult result = UrlExpansionResult(
    status: UrlExpansionStatus.noRedirect,
  );
  @override
  Future<UrlExpansionResult> expandUrl(String url) async => result;
}

void main() {
  late _Datasource datasource;
  late _Expander expander;
  late OfficialBrandRepositoryImpl repository;
  late ProcessUrlUseCase process;
  late DateTime now;
  final evaluate = EvaluateUrlRiskUseCase();

  setUp(() {
    now = DateTime.utc(2026, 11, 16);
    datasource = _Datasource();
    expander = _Expander();
    repository = OfficialBrandRepositoryImpl(
      datasource: datasource,
      clock: () => now,
    );
    process = ProcessUrlUseCase(
      normalizer: UrlNormalizer(),
      expander: expander,
      detectBrandImpersonationUseCase: DetectBrandImpersonationUseCase(
        repository: repository,
      ),
    );
  });

  Future<RiskEvaluationResult> analyze(String url) async =>
      evaluate(await process(url));
  List<RiskEvidenceId> ids(RiskEvaluationResult result) =>
      result.evidences.map((e) => e.id).toList();

  test('official domain and legitimate subdomain are locally green', () async {
    for (final host in ['bancolombia.com', 'personas.bancolombia.com']) {
      final result = await analyze('https://$host/login');
      expect(result.level, RiskLevel.green);
      expect(result.completeness, RiskAnalysisCompleteness.complete);
      expect(result.hasUncertainty, isFalse);
      expect(ids(result), [RiskEvidenceId.officialDomain]);
      expect(result.summary, contains('No garantiza seguridad absoluta'));
    }
  });

  test('unknown domain is yellow even with complete local checks', () async {
    final result = await analyze('https://independent-shop.net');
    expect(result.level, RiskLevel.yellow);
    expect(ids(result), contains(RiskEvidenceId.unknownDomain));
    expect(result.completeness, RiskAnalysisCompleteness.complete);
  });

  test(
    'US-07 distance one is red, more distant similarity stays yellow',
    () async {
      final strong = await analyze('https://bancol0mbia.com');
      final moderate = await analyze('https://banc0l0mbia.com');
      expect(strong.level, RiskLevel.red);
      expect(moderate.level, RiskLevel.yellow);
      expect(ids(strong), contains(RiskEvidenceId.brandImpersonation));
    },
  );

  test('same brand with another suffix reuses US-07', () async {
    final result = await analyze('https://bancolombia.net');
    expect(result.level, isNot(RiskLevel.green));
    expect(ids(result), contains(RiskEvidenceId.brandImpersonation));
  });

  test(
    'explicit HTTP downgrades official domain, never makes it red',
    () async {
      final result = await analyze('http://bancolombia.com');
      expect(result.level, RiskLevel.yellow);
      expect(
        ids(result),
        containsAll([
          RiskEvidenceId.explicitHttp,
          RiskEvidenceId.officialDomain,
        ]),
      );
    },
  );

  for (final host in ['8.8.8.8', '[2606:4700:4700::1111]']) {
    test('IP host $host is yellow', () async {
      final result = await analyze('https://$host/');
      expect(result.level, RiskLevel.yellow);
      expect(ids(result), contains(RiskEvidenceId.ipHost));
    });
  }

  test(
    'whole official domain inside foreign subdomain is strong deception',
    () async {
      final result = await analyze(
        'https://bancolombia.com.independent-shop.net',
      );
      expect(result.level, RiskLevel.red);
      expect(ids(result), contains(RiskEvidenceId.deceptiveBrandSubdomain));
    },
  );

  test('brand label alone is moderate; substrings are not matches', () async {
    final moderate = await analyze('https://bancolombia.independent-shop.net');
    final substring = await analyze(
      'https://notbancolombia.independent-shop.net',
    );
    expect(moderate.level, RiskLevel.yellow);
    expect(ids(moderate), contains(RiskEvidenceId.brandLabelInSubdomain));
    expect(
      ids(substring),
      isNot(contains(RiskEvidenceId.brandLabelInSubdomain)),
    );
  });

  test(
    'confirmed shortener evaluates destination, reusing existing brand result',
    () async {
      expander.result = UrlExpansionResult(
        status: UrlExpansionStatus.resolved,
        redirectCount: 1,
        verifiedDestination: 'https://bancolombia.com/',
        lastHttpStatus: 200,
      );
      final processed = await process('https://bit.ly/example');
      final calls = datasource.calls;
      final result = evaluate(processed);
      expect(result.level, RiskLevel.green);
      expect(result.evaluatedUrl, 'https://bancolombia.com/');
      expect(datasource.calls, calls);
      expect(
        processed.brandImpersonation!.status,
        BrandMatchStatus.officialVerified,
      );
    },
  );

  test(
    'HTTP shortener entry remains a signal even with HTTPS destination',
    () async {
      expander.result = UrlExpansionResult(
        status: UrlExpansionStatus.resolved,
        redirectCount: 1,
        verifiedDestination: 'https://bancolombia.com/',
        lastHttpStatus: 200,
      );
      expect((await analyze('http://bit.ly/example')).level, RiskLevel.yellow);
    },
  );

  test(
    'unresolved shortener never treats its brand result as final destination',
    () async {
      final official = (await process('https://bancolombia.com'))
          .brandImpersonation;
      final result = evaluate(
        UrlProcessingResult(
          contentRaw: 'https://bit.ly/a',
          normalizedUrl: 'https://bit.ly/a',
          isUrl: true,
          wasShortened: true,
          expansion: expander.result,
          brandImpersonation: official,
        ),
      );
      expect(result.level, RiskLevel.yellow);
      expect(result.evaluatedUrl, isNull);
      expect(result.completeness, RiskAnalysisCompleteness.partial);
      expect(ids(result), contains(RiskEvidenceId.unresolvedShortener));
      expect(ids(result), isNot(contains(RiskEvidenceId.officialDomain)));
    },
  );

  for (final status in [
    UrlExpansionStatus.failed,
    UrlExpansionStatus.blocked,
    UrlExpansionStatus.timeout,
    UrlExpansionStatus.unsupportedPlatform,
    UrlExpansionStatus.cancelled,
  ]) {
    test(
      'expansion ${status.name} preserves uncertainty and ignores announcement',
      () async {
        expander.result = UrlExpansionResult(
          status: status,
          failureReason:
              status == UrlExpansionStatus.failed ||
                  status == UrlExpansionStatus.blocked
              ? UrlExpansionFailureReason.forbiddenDestination
              : null,
          announcedDestination: 'https://bancolombia.com/',
        );
        final result = await analyze('https://bit.ly/a');
        expect(result.level, RiskLevel.yellow);
        expect(result.evaluatedUrl, isNull);
        expect(
          result.uncertaintyReasons,
          contains(RiskEvidenceId.expansionIncomplete),
        );
        expect(ids(result), isNot(contains(RiskEvidenceId.officialDomain)));
      },
    );
  }

  test('catalog failure is explicit, not reliable noMatch', () async {
    datasource.fail = true;
    final processed = await process('https://bancolombia.com');
    expect(
      processed.brandImpersonation!.catalogStatus,
      BrandCatalogStatus.unavailable,
    );
    final result = evaluate(processed);
    expect(result.level, RiskLevel.yellow);
    expect(
      result.uncertaintyReasons,
      contains(RiskEvidenceId.catalogUnavailable),
    );
  });

  test('stale official match cannot become green; fresh cache can', () async {
    expect((await analyze('https://bancolombia.com')).level, RiskLevel.green);
    datasource.fail = true;
    expect((await analyze('https://bancolombia.com')).level, RiskLevel.green);
    now = now.add(const Duration(minutes: 6));
    final stale = await analyze('https://bancolombia.com');
    expect(stale.level, RiskLevel.yellow);
    expect(stale.uncertaintyReasons, contains(RiskEvidenceId.catalogStale));
    expect(ids(stale), contains(RiskEvidenceId.officialDomain));
  });

  test('successful empty catalog is distinct from failed catalog', () async {
    datasource.empty = true;
    final result = await analyze('https://bancolombia.com');
    expect(result.level, RiskLevel.yellow);
    expect(result.hasUncertainty, isFalse);
    expect(ids(result), contains(RiskEvidenceId.unknownDomain));
  });

  test('red takes precedence over HTTP and expansion uncertainty', () async {
    final processed = await process('http://bancol0mbia.com');
    final result = evaluate(
      UrlProcessingResult(
        contentRaw: processed.contentRaw,
        normalizedUrl: processed.normalizedUrl,
        isUrl: true,
        wasShortened: false,
        brandImpersonation: processed.brandImpersonation,
        expansion: UrlExpansionResult(
          status: UrlExpansionStatus.blocked,
          failureReason: UrlExpansionFailureReason.forbiddenDestination,
        ),
      ),
    );
    expect(result.level, RiskLevel.red);
    expect(result.completeness, RiskAnalysisCompleteness.partial);
    expect(
      ids(result),
      containsAll([
        RiskEvidenceId.explicitHttp,
        RiskEvidenceId.expansionIncomplete,
        RiskEvidenceId.brandImpersonation,
      ]),
    );
  });

  test(
    'length, subdomains, credentials and unusual port cannot alone make red',
    () async {
      final result = await analyze(
        'https://user:pass@a.b.c.d.bancolombia.com:8443/${'x' * 2050}',
      );
      expect(result.level, RiskLevel.yellow);
      expect(
        ids(result),
        containsAll([
          RiskEvidenceId.longUrl,
          RiskEvidenceId.manySubdomains,
          RiskEvidenceId.embeddedCredentials,
          RiskEvidenceId.unusualPort,
        ]),
      );
    },
  );

  test('brand observations must belong to evaluated target', () async {
    final official = (await process('https://bancolombia.com'))
        .brandImpersonation;
    final result = evaluate(
      UrlProcessingResult(
        contentRaw: 'https://independent-shop.net',
        normalizedUrl: 'https://independent-shop.net/',
        isUrl: true,
        wasShortened: false,
        expansion: UrlExpansionResult(status: UrlExpansionStatus.notAttempted),
        brandImpersonation: official,
      ),
    );
    expect(result.level, RiskLevel.yellow);
    expect(
      result.uncertaintyReasons,
      contains(RiskEvidenceId.brandTargetMismatch),
    );
  });

  test(
    'missing brand and legacy expansion observations cannot enable green',
    () async {
      final result = evaluate(
        const UrlProcessingResult(
          contentRaw: 'https://bancolombia.com',
          normalizedUrl: 'https://bancolombia.com/',
          isUrl: true,
          wasShortened: false,
        ),
      );
      expect(result.level, RiskLevel.yellow);
      expect(
        result.uncertaintyReasons,
        containsAll([
          RiskEvidenceId.missingExpansionObservation,
          RiskEvidenceId.brandAnalysisMissing,
        ]),
      );
    },
  );

  test(
    'legacy brand status without catalog metadata cannot enable green',
    () async {
      final processed = await process('https://bancolombia.com');
      final original = processed.brandImpersonation!;
      final result = evaluate(
        UrlProcessingResult(
          contentRaw: processed.contentRaw,
          normalizedUrl: processed.normalizedUrl,
          isUrl: true,
          wasShortened: false,
          expansion: processed.expansion,
          brandImpersonation: BrandImpersonationResult(
            status: original.status,
            evaluatedRootDomain: original.evaluatedRootDomain,
            matchedBrand: original.matchedBrand,
          ),
        ),
      );
      expect(result.level, RiskLevel.yellow);
      expect(
        result.uncertaintyReasons,
        contains(RiskEvidenceId.catalogUnknown),
      );
    },
  );

  test('non URL is not applicable, never green', () async {
    final result = await analyze('texto QR sin URL');
    expect(result.level, RiskLevel.yellow);
    expect(result.completeness, RiskAnalysisCompleteness.notApplicable);
    expect(result.evaluatedUrl, isNull);
  });

  test('results expose immutable collections', () async {
    final result = await analyze('https://bancolombia.com');
    expect(() => result.evidences.clear(), throwsUnsupportedError);
    expect(() => result.uncertaintyReasons.clear(), throwsUnsupportedError);
  });
}
