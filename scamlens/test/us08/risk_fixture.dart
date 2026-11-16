import 'package:scamlens/features/smishing/domain/services/sms_url_extractor.dart';
import 'package:scamlens/shared/analysis_progress/domain/analysis_progress.dart';
import 'package:scamlens/features/smishing/domain/usecases/analyze_sms_usecase.dart';
import 'package:scamlens/shared/brand_impersonation/domain/entities/official_brand.dart';
import 'package:scamlens/shared/brand_impersonation/domain/entities/official_brand_catalog.dart';
import 'package:scamlens/shared/brand_impersonation/domain/repositories/official_brand_repository.dart';
import 'package:scamlens/shared/brand_impersonation/domain/usecases/detect_brand_impersonation_usecase.dart';
import 'package:scamlens/shared/url_processing/domain/entities/url_expansion_result.dart';
import 'package:scamlens/shared/url_processing/domain/entities/url_processing_result.dart';
import 'package:scamlens/shared/url_processing/domain/services/url_expander.dart';
import 'package:scamlens/shared/url_processing/domain/services/url_normalizer.dart';
import 'package:scamlens/shared/url_processing/domain/usecases/process_url_usecase.dart';
import 'package:scamlens/shared/url_risk/domain/entities/risk_evaluation_result.dart';
import 'package:scamlens/shared/url_risk/domain/usecases/evaluate_url_risk_usecase.dart';

class TestCatalog
    implements OfficialBrandRepository, OfficialBrandCatalogReader {
  int calls = 0;
  BrandCatalogStatus status = BrandCatalogStatus.available;
  final brands = [
    OfficialBrand(
      id: 'b1',
      entityName: 'Bancolombia',
      officialDomain: 'bancolombia.com',
      category: 'Banca',
      active: true,
      createdIn: DateTime.utc(2026, 11, 12),
    ),
  ];

  @override
  Future<OfficialBrandCatalog> getCatalogSnapshot() async {
    calls++;
    return OfficialBrandCatalog(
      brands: status == BrandCatalogStatus.unavailable ? [] : brands,
      status: status,
    );
  }

  @override
  Future<List<OfficialBrand>> getActiveBrands() async =>
      (await getCatalogSnapshot()).brands;
  @override
  void invalidateCache() {}
}

class TestExpander implements UrlExpander {
  int calls = 0;
  Future<UrlExpansionResult>? pending;
  UrlExpansionResult result = UrlExpansionResult(
    status: UrlExpansionStatus.timeout,
    announcedDestination: 'https://unconfirmed.example/private',
  );
  @override
  Future<UrlExpansionResult> expandUrl(String url) async {
    calls++;
    return pending ?? Future.value(result);
  }
}

class CountingProcessor extends ProcessUrlUseCase {
  int calls = 0;
  CountingProcessor(TestCatalog catalog, TestExpander expander)
    : super(
        normalizer: UrlNormalizer(),
        expander: expander,
        detectBrandImpersonationUseCase: DetectBrandImpersonationUseCase(
          repository: catalog,
        ),
      );
  @override
  Future<UrlProcessingResult> call(
    String content, {
    AnalysisProgressCallback? onProgress,
  }) {
    calls++;
    return super.call(content, onProgress: onProgress);
  }
}

class CountingEvaluator extends EvaluateUrlRiskUseCase {
  final inputs = <UrlProcessingResult>[];
  @override
  RiskEvaluationResult call(
    UrlProcessingResult input, {
    AnalysisProgressCallback? onProgress,
  }) {
    inputs.add(input);
    return super.call(input, onProgress: onProgress);
  }
}

class RiskFixture {
  final catalog = TestCatalog();
  final expander = TestExpander();
  final evaluator = CountingEvaluator();
  late final processor = CountingProcessor(catalog, expander);
  late final sms = AnalyzeSmsUseCase(
    extractor: SmsUrlExtractor(),
    processUrlUseCase: processor,
    evaluateUrlRiskUseCase: evaluator,
  );
}
