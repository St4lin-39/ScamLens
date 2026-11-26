import 'package:flutter/material.dart';
import 'package:scamlens/shared/analysis_progress/domain/analysis_progress.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:scamlens/features/scanner/ui/bloc/scanner_bloc.dart';
import 'package:scamlens/features/scanner/ui/screens/scanner_screen.dart';
import 'package:scamlens/shared/url_processing/domain/entities/url_expansion_result.dart';
import 'package:scamlens/shared/url_processing/domain/entities/url_processing_result.dart';
import 'package:scamlens/shared/url_processing/domain/services/url_expander.dart';
import 'package:scamlens/shared/url_processing/domain/services/url_normalizer.dart';
import 'package:scamlens/shared/url_processing/domain/usecases/process_url_usecase.dart';
import 'package:scamlens/theme/app_theme.dart';

// Only the camera platform is replaced; production widget/layout is exercised.
class _Camera extends MobileScannerPlatform {
  @override
  Stream<BarcodeCapture?> get barcodesStream => const Stream.empty();
  @override
  Stream<TorchState> get torchStateStream => const Stream.empty();
  @override
  Stream<double> get zoomScaleStateStream => const Stream.empty();
  @override
  Widget buildCameraView() => const SizedBox.expand();
  @override
  Future<MobileScannerViewAttributes> start(StartOptions options) async =>
      const MobileScannerViewAttributes(
        cameraDirection: CameraFacing.back,
        currentTorchMode: TorchState.off,
        size: Size(640, 480),
        numberOfCameras: 1,
      );
  @override
  Future<void> stop() async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> dispose() async {}
  @override
  Future<void> updateScanWindow(Rect? window) async {}
}

class _UnusedExpander implements UrlExpander {
  @override
  Future<UrlExpansionResult> expandUrl(String url) =>
      throw StateError('No HTTP in UI tests');
}

class _Processor extends ProcessUrlUseCase {
  final UrlProcessingResult result;
  _Processor(this.result)
    : super(normalizer: UrlNormalizer(), expander: _UnusedExpander());
  @override
  Future<UrlProcessingResult> call(
    String content, {
    AnalysisProgressCallback? onProgress,
  }) async => result;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MobileScannerPlatform original;
  setUp(() {
    original = MobileScannerPlatform.instance;
    MobileScannerPlatform.instance = _Camera();
  });
  tearDown(() {
    MobileScannerPlatform.instance = original;
  });

  Future<ScannerBloc> open(
    WidgetTester tester,
    UrlProcessingResult result,
  ) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final bloc = ScannerBloc(processUrlUseCase: _Processor(result));
    addTearDown(bloc.close);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: BlocProvider.value(value: bloc, child: const ScannerScreen()),
      ),
    );
    bloc.add(QRCodeScannedEvent(rawValue: result.contentRaw));
    await tester.pumpAndSettle();
    return bloc;
  }

  testWidgets(
    'QR confirmed destination stays in existing card and details reset closed',
    (tester) async {
      final result = UrlProcessingResult(
        contentRaw: 'https://BIT.LY/a',
        normalizedUrl: 'https://bit.ly/a',
        isUrl: true,
        wasShortened: true,
        expansion: UrlExpansionResult(
          status: UrlExpansionStatus.resolved,
          redirectCount: 2,
          verifiedDestination: 'https://destination.example/path',
          lastHttpStatus: 200,
        ),
      );
      final bloc = await open(tester, result);
      expect((bloc.state as ScannerSuccessState).result, same(result));
      expect(find.byType(MobileScanner), findsOneWidget);
      expect(find.text('Detected QR content:'), findsOneWidget);
      expect(find.text('Normalized URL:'), findsOneWidget);
      expect(find.text('Confirmed HTTP destination:'), findsOneWidget);
      expect(find.text('https://destination.example/path'), findsOneWidget);
      expect(find.text('Unmasked real destination:'), findsNothing);
      expect(find.text('HTTP status: 200'), findsNothing);
      await tester.ensureVisible(find.text('Processing details'));
      await tester.tap(find.text('Processing details'));
      await tester.pumpAndSettle();
      expect(
        find.text('Status: Destination confirmed via HTTP'),
        findsOneWidget,
      );
      expect(find.text('Redirects: 2'), findsOneWidget);
      expect(find.text('HTTP status: 200'), findsOneWidget);
      await tester.ensureVisible(find.text('SCAN ANOTHER QR'));
      await tester.tap(find.text('SCAN ANOTHER QR'));
      await tester.pumpAndSettle();
      expect(bloc.state, isA<ScannerActiveState>());
      bloc.add(QRCodeScannedEvent(rawValue: result.contentRaw));
      await tester.pumpAndSettle();
      expect(find.text('HTTP status: 200'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final status in [
    UrlExpansionStatus.timeout,
    UrlExpansionStatus.blocked,
    UrlExpansionStatus.noRedirect,
    UrlExpansionStatus.unsupportedPlatform,
  ]) {
    testWidgets('QR $status never presents announcement as a destination', (
      tester,
    ) async {
      const announced = 'https://unconfirmed.example/private';
      final noRedirect = status == UrlExpansionStatus.noRedirect;
      final unavailable = status == UrlExpansionStatus.unsupportedPlatform;
      final expansion = UrlExpansionResult(
        status: status,
        failureReason: status == UrlExpansionStatus.blocked
            ? UrlExpansionFailureReason.forbiddenDestination
            : null,
        redirectCount: noRedirect || unavailable ? 0 : 1,
        announcedDestination: noRedirect || unavailable ? null : announced,
        lastHttpStatus: unavailable
            ? null
            : noRedirect
            ? 200
            : 302,
      );
      await open(
        tester,
        UrlProcessingResult(
          contentRaw: 'https://bit.ly/a',
          normalizedUrl: 'https://bit.ly/a',
          isUrl: true,
          wasShortened: true,
          expansion: expansion,
        ),
      );
      expect(find.text('SHORTENER DETECTED'), findsOneWidget);
      expect(find.text('Confirmed HTTP destination:'), findsNothing);
      expect(find.text(announced), findsNothing);
      expect(find.textContaining('Status:'), findsNothing);
      await tester.ensureVisible(find.text('Processing details'));
      await tester.tap(find.text('Processing details'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Status:'), findsOneWidget);
      expect(find.text(announced), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('QR legacy shortener without expansion does not imply success', (
    tester,
  ) async {
    await open(
      tester,
      const UrlProcessingResult(
        contentRaw: 'https://bit.ly/a',
        normalizedUrl: 'https://bit.ly/a',
        isUrl: true,
        wasShortened: true,
      ),
    );
    expect(find.text('SHORTENER DETECTED'), findsOneWidget);
    expect(find.text('Normalized URL:'), findsOneWidget);
    expect(find.text('Confirmed HTTP destination:'), findsNothing);
    expect(find.text('Processing details'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('QR plain text keeps original result and scan button', (
    tester,
  ) async {
    await open(
      tester,
      UrlProcessingResult(
        contentRaw: 'Plain text',
        normalizedUrl: 'Plain text',
        isUrl: false,
        wasShortened: false,
        expansion: UrlExpansionResult(status: UrlExpansionStatus.notAttempted),
      ),
    );
    expect(find.text('DETECTED TEXT'), findsOneWidget);
    expect(find.text('Plain text'), findsOneWidget);
    expect(find.text('SCAN ANOTHER QR'), findsOneWidget);
    expect(find.text('Processing details'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
