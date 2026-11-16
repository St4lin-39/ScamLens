import 'dart:async';

import 'package:flutter/material.dart';
import 'package:scamlens/components/analysis_progress_view.dart';
import 'package:scamlens/shared/analysis_progress/domain/analysis_progress.dart';
import 'package:scamlens/shared/url_processing/domain/entities/url_expansion_result.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:scamlens/components/risk_traffic_light.dart';
import 'package:scamlens/features/scanner/ui/bloc/scanner_bloc.dart';
import 'package:scamlens/features/scanner/ui/screens/scanner_screen.dart';
import 'package:scamlens/features/smishing/ui/bloc/smishing_bloc.dart';
import 'package:scamlens/features/smishing/ui/screens/smishing_screen.dart';
import 'package:scamlens/shared/url_risk/domain/entities/risk_evaluation_result.dart';
import 'package:scamlens/theme/app_theme.dart';

import 'risk_fixture.dart';

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  void size(WidgetTester tester, Size dimensions) {
    tester.view.physicalSize = dimensions;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }
  testWidgets(
    'progress component distinguishes active, completed, skipped, failed and unavailable',
    (tester) async {
      final progress = AnalysisProgressSnapshot([
        const AnalysisProgress(
          AnalysisStage.normalizeUrl,
          AnalysisStageStatus.completed,
        ),
        const AnalysisProgress(
          AnalysisStage.expandShortener,
          AnalysisStageStatus.failed,
          reason: AnalysisProgressReason.timeout,
        ),
        const AnalysisProgress(
          AnalysisStage.brandCheck,
          AnalysisStageStatus.skipped,
          reason: AnalysisProgressReason.notApplicable,
        ),
        const AnalysisProgress(
          AnalysisStage.evaluateRisk,
          AnalysisStageStatus.active,
        ),
        const AnalysisProgress(
          AnalysisStage.prepareResult,
          AnalysisStageStatus.unavailable,
          reason: AnalysisProgressReason.unsupportedPlatform,
        ),
      ]);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AnalysisProgressView(progress: progress),
            ),
          ),
        ),
      );
      for (final status in [
        'Completada',
        'Fallida',
        'Omitida',
        'En curso',
        'No disponible',
      ]) {
        expect(find.textContaining('· $status'), findsOneWidget);
      }
      expect(find.textContaining('Tiempo agotado'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'QR shows actual pending expansion, then unavailable history and existing traffic light',
    (tester) async {
      size(tester, const Size(900, 1800));
      final original = MobileScannerPlatform.instance;
      MobileScannerPlatform.instance = _Camera();
      addTearDown(() => MobileScannerPlatform.instance = original);
      final fixture = RiskFixture();
      final pending = Completer<UrlExpansionResult>();
      fixture.expander.pending = pending.future;
      final bloc = ScannerBloc(
        processUrlUseCase: fixture.processor,
        evaluateUrlRiskUseCase: fixture.evaluator,
      );
      addTearDown(bloc.close);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          home: BlocProvider.value(value: bloc, child: const ScannerScreen()),
        ),
      );
      bloc.add(QRCodeScannedEvent(rawValue: 'https://bit.ly/a'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Comprobando destino del acortador · En curso'),
        findsOneWidget,
      );
      expect(find.byType(RiskTrafficLight), findsNothing);
      pending.complete(
        UrlExpansionResult(status: UrlExpansionStatus.unsupportedPlatform),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<RiskTrafficLight>(find.byType(RiskTrafficLight))
            .evaluation
            .level,
        RiskLevel.yellow,
      );
      final progress = (bloc.state as ScannerSuccessState).progress;
      expect(
        progress.stages
            .firstWhere((e) => e.stage == AnalysisStage.expandShortener)
            .status,
        AnalysisStageStatus.unavailable,
      );
      await tester.ensureVisible(find.text('Etapas del análisis'));
      await tester.tap(find.text('Etapas del análisis'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining(
          'Comprobando destino del acortador · No disponible',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'La comprobación del acortador no está disponible en esta plataforma.',
        ),
        findsOneWidget,
      );
      expect(fixture.expander.calls, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'SMS progress counts unique links and preserves independent final traffic lights',
    (tester) async {
      size(tester, const Size(1000, 2400));
      final fixture = RiskFixture();
      final pending = Completer<UrlExpansionResult>();
      fixture.expander.pending = pending.future;
      final bloc = SmishingBloc(analyzeSmsUseCase: fixture.sms);
      addTearDown(bloc.close);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          home: BlocProvider.value(value: bloc, child: const SmishingScreen()),
        ),
      );
      await tester.enterText(
        find.byType(TextField),
        'https://bancolombia.com https://bit.ly/a https://bancolombia.com',
      );
      await tester.tap(find.text('Analizar enlaces'));
      await tester.pumpAndSettle();
      expect(find.text('Enlace único 2 de 2'), findsOneWidget);
      expect(
        find.textContaining('Comprobando destino del acortador · En curso'),
        findsOneWidget,
      );
      pending.complete(UrlExpansionResult(status: UrlExpansionStatus.timeout));
      await tester.pumpAndSettle();
      expect(
        tester
            .widgetList<RiskTrafficLight>(find.byType(RiskTrafficLight))
            .map((w) => w.evaluation.level),
        [RiskLevel.green, RiskLevel.yellow, RiskLevel.green],
      );
      expect(fixture.processor.calls, 2);
      expect(fixture.expander.calls, 1);
      expect(fixture.evaluator.inputs.length, 2);
      expect(find.text('Análisis en curso'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  for (final (url, title, icon, color) in [
    (
      'https://bancolombia.com',
      'Verde · Dominio oficial reconocido',
      Icons.verified_user_outlined,
      AppColors.safeGreen,
    ),
    (
      'https://independent-shop.net',
      'Amarillo · Precaución',
      Icons.warning_amber_rounded,
      AppColors.warningYellow,
    ),
    (
      'https://bancol0mbia.com',
      'Rojo · Posible suplantación',
      Icons.gpp_bad_outlined,
      AppColors.error,
    ),
  ]) {
    testWidgets(
      'shared traffic light presents icon, text, color and details: $title',
      (tester) async {
        size(tester, const Size(360, 1200));
        final fixture = RiskFixture();
        final risk = fixture.evaluator(await fixture.processor(url));
        await tester.pumpWidget(
          MaterialApp(
            theme: buildTheme(),
            home: Scaffold(
              body: SingleChildScrollView(
                child: RiskTrafficLight(evaluation: risk),
              ),
            ),
          ),
        );
        expect(find.text(title), findsOneWidget);
        expect(tester.widget<Icon>(find.byIcon(icon)).color, color);
        expect(find.text(risk.summary), findsOneWidget);
        expect(find.textContaining('Enlace observado:'), findsNothing);
        await tester.tap(find.text('Detalles de la evaluación'));
        await tester.pumpAndSettle();
        expect(
          find.textContaining(risk.evidences.first.justification),
          findsOneWidget,
        );
        expect(
          find.textContaining('Sin servicios de reputación'),
          findsOneWidget,
        );
        expect(find.text('URL evaluada: $url'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'red blocks injected direct navigation while details remain usable',
    (tester) async {
      final fixture = RiskFixture();
      final risk = fixture.evaluator(
        await fixture.processor('https://bancol0mbia.com'),
      );
      final opened = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: RiskTrafficLight(evaluation: risk, onOpenUrl: opened.add),
            ),
          ),
        ),
      );
      expect(
        tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
        isNull,
      );
      await tester.tap(find.text('Abrir enlace'));
      expect(opened, isEmpty);
      await tester.tap(find.text('Detalles de la evaluación'));
      await tester.pumpAndSettle();
      expect(find.textContaining('distancia de edicion'), findsOneWidget);
      expect(opened, isEmpty);
    },
  );

  testWidgets(
    'green navigation uses evaluated URL and explicitly disclaims safety',
    (tester) async {
      final fixture = RiskFixture();
      const url = 'https://bancolombia.com/?id=7';
      final risk = fixture.evaluator(await fixture.processor(url));
      final opened = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RiskTrafficLight(evaluation: risk, onOpenUrl: opened.add),
          ),
        ),
      );
      expect(
        find.textContaining('No garantiza seguridad absoluta'),
        findsOneWidget,
      );
      await tester.tap(find.text('Abrir enlace'));
      expect(opened, [url]);
    },
  );

  testWidgets('uncertain shortener shows no announced target and cannot open', (
    tester,
  ) async {
    final fixture = RiskFixture();
    final risk = fixture.evaluator(await fixture.processor('https://bit.ly/a'));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: RiskTrafficLight(
              evaluation: risk,
              onOpenUrl: (_) => fail('Must not open'),
            ),
          ),
        ),
      ),
    );
    expect(
      find.text('Evaluación parcial: información insuficiente'),
      findsOneWidget,
    );
    expect(
      tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
      isNull,
    );
    await tester.tap(find.text('Detalles de la evaluación'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('no tiene un destino confirmado'),
      findsOneWidget,
    );
    expect(find.textContaining('unconfirmed.example'), findsNothing);
  });

  for (final (url, level) in [
    ('https://bancolombia.com', RiskLevel.green),
    ('https://independent-shop.net', RiskLevel.yellow),
    ('https://bancol0mbia.com', RiskLevel.red),
    ('https://bit.ly/a', RiskLevel.yellow),
  ]) {
    testWidgets('real QR screen displays $level for $url without navigation', (
      tester,
    ) async {
      size(tester, const Size(900, 1800));
      final original = MobileScannerPlatform.instance;
      MobileScannerPlatform.instance = _Camera();
      addTearDown(() => MobileScannerPlatform.instance = original);
      final fixture = RiskFixture();
      final bloc = ScannerBloc(
        processUrlUseCase: fixture.processor,
        evaluateUrlRiskUseCase: fixture.evaluator,
      );
      addTearDown(bloc.close);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          home: BlocProvider.value(value: bloc, child: const ScannerScreen()),
        ),
      );
      bloc.add(QRCodeScannedEvent(rawValue: url));
      await tester.pumpAndSettle();
      final light = tester.widget<RiskTrafficLight>(
        find.byType(RiskTrafficLight),
      );
      expect(light.evaluation.level, level);
      expect(light.onOpenUrl, isNull);
      expect(find.text('Abrir enlace'), findsNothing);
      if (level == RiskLevel.red) {
        expect(
          find.text('Apertura directa bloqueada por posible suplantación.'),
          findsOneWidget,
        );
      }
      await tester.ensureVisible(find.text('Detalles de la evaluación'));
      await tester.tap(find.text('Detalles de la evaluación'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Enlace observado:'), findsWidgets);
      expect(fixture.processor.calls, 1);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'real SMS screen keeps distinct traffic lights and details for multiple URLs',
    (tester) async {
      size(tester, const Size(1000, 3000));
      final fixture = RiskFixture();
      final bloc = SmishingBloc(analyzeSmsUseCase: fixture.sms);
      addTearDown(bloc.close);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          home: BlocProvider.value(value: bloc, child: const SmishingScreen()),
        ),
      );
      await tester.enterText(
        find.byType(TextField),
        'https://bancolombia.com '
        'https://independent-shop.net https://bancol0mbia.com https://bit.ly/a',
      );
      await tester.tap(find.text('Analizar enlaces'));
      await tester.pumpAndSettle();
      final lights = tester
          .widgetList<RiskTrafficLight>(find.byType(RiskTrafficLight))
          .toList();
      expect(lights.map((l) => l.evaluation.level), [
        RiskLevel.green,
        RiskLevel.yellow,
        RiskLevel.red,
        RiskLevel.yellow,
      ]);
      expect(lights.last.evaluation.hasUncertainty, isTrue);
      expect(find.text('Abrir enlace'), findsNothing);
      expect(
        find.text('Apertura directa bloqueada por posible suplantación.'),
        findsOneWidget,
      );
      for (var i = 0; i < lights.length; i++) {
        final details = find.descendant(
          of: find.byType(RiskTrafficLight).at(i),
          matching: find.text('Detalles de la evaluación'),
        );
        await tester.ensureVisible(details);
        await tester.tap(details);
        await tester.pumpAndSettle();
        final evidence = find.descendant(
          of: find.byType(RiskTrafficLight).at(i),
          matching: find.textContaining('Enlace observado:'),
        );
        expect(evidence, findsWidgets);
      }
      expect(fixture.processor.calls, 4);
      expect(fixture.evaluator.inputs.length, 4);
      expect(tester.takeException(), isNull);
    },
  );
}
