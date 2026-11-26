import 'dart:async';

import 'package:scamlens/shared/analysis_progress/domain/analysis_progress.dart';

import 'package:scamlens/features/home/ui/home_screen.dart';
import 'package:scamlens/features/auth/domain/entities/profile.dart';
import 'package:scamlens/features/auth/domain/usescases/get_profile_usecase.dart';
import 'package:scamlens/features/auth/domain/usescases/sign_out_usecase.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scamlens/shared/url_processing/domain/entities/url_expansion_result.dart';
import 'package:scamlens/features/smishing/domain/entities/sms_analysis_result.dart';
import 'package:scamlens/features/smishing/domain/services/sms_url_extractor.dart';
import 'package:scamlens/features/smishing/domain/usecases/analyze_sms_usecase.dart';
import 'package:scamlens/features/smishing/ui/bloc/smishing_bloc.dart';
import 'package:scamlens/features/smishing/ui/screens/smishing_screen.dart';
import 'package:scamlens/shared/url_processing/domain/entities/url_processing_result.dart';
import 'package:scamlens/shared/url_processing/domain/services/url_expander.dart';
import 'package:scamlens/shared/url_processing/domain/services/url_normalizer.dart';
import 'package:scamlens/shared/url_processing/domain/usecases/process_url_usecase.dart';
import 'package:scamlens/theme/app_theme.dart';

class FakeExpander implements UrlExpander {
  @override
  Future<UrlExpansionResult> expandUrl(String url) async => UrlExpansionResult(
    status: UrlExpansionStatus.resolved,
    redirectCount: 1,
    verifiedDestination: 'https://example.com/destination',
    lastHttpStatus: 200,
  );
}

class ControlledAnalysis implements AnalyzeSmsUseCase {
  final pending = Completer<SmsAnalysisResult>();
  @override
  Future<SmsAnalysisResult> call(
    String text, {
    AnalysisProgressCallback? onProgress,
  }) => pending.future;
  @override
  Never get extractor => throw UnimplementedError();
  @override
  Never get processUrlUseCase => throw UnimplementedError();
}

class FakeProfileUseCase implements GetProfileUseCase {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeSignOut implements SignOutUseCase {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AnalyzeSmsUseCase useCase;
  setUp(() {
    useCase = AnalyzeSmsUseCase(
      extractor: SmsUrlExtractor(),
      processUrlUseCase: ProcessUrlUseCase(
        normalizer: UrlNormalizer(),
        expander: FakeExpander(),
      ),
    );
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });
  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: BlocProvider(
          create: (_) => SmishingBloc(analyzeSmsUseCase: useCase),
          child: const SmishingScreen(),
        ),
      ),
    );
  }

  Future<void> analyze(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    await tester.tap(find.text('Analyze links'));
    await tester.pumpAndSettle();
  }

  testWidgets('initial state and empty input validation', (tester) async {
    await open(tester);
    expect(find.text('SMS Links'), findsOneWidget);
    expect(find.byType(SelectableText), findsNothing);
    await tester.tap(find.text('Analyze links'));
    await tester.pump();
    expect(
      find.text('Enter an SMS message to analyze.'),
      findsOneWidget,
    );
  });
  testWidgets('manual message with no URLs and reset', (tester) async {
    await open(tester);
    await analyze(tester, 'A message without links');
    expect(find.text('No links were found in this SMS.'), findsOneWidget);
    await tester.ensureVisible(find.text('Analyze another SMS'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Analyze another SMS'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
    expect(find.text('No links were found in this SMS.'), findsNothing);
    await analyze(tester, 'https://example.com');
    expect(find.text('Detected links: 1'), findsOneWidget);
  });
  testWidgets('multiple URLs keep occurrence order including duplicates', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await open(tester);
    await analyze(
      tester,
      'https://example.com/a https://bit.ly/demo https://example.com/a',
    );
    expect(find.text('Detected links: 3'), findsOneWidget);
    await tester.ensureVisible(find.text('Link 3'));
    await tester.pumpAndSettle();
    final urls = tester
        .widgetList<SelectableText>(find.byType(SelectableText))
        .map((w) => w.data)
        .toList();
    expect(urls, [
      'https://example.com/a',
      'https://example.com/a',
      'https://bit.ly/demo',
      'https://bit.ly/demo',
      'https://example.com/destination',
      'https://example.com/a',
      'https://example.com/a',
    ]);
    expect(find.textContaining('Cannot confirm'), findsNothing);
    expect(find.text('Confirmed HTTP destination:'), findsOneWidget);
    expect(find.text('Processing details'), findsNWidgets(3));
    expect(find.textContaining('Status:'), findsNothing);
    await tester.ensureVisible(find.text('Processing details').at(1));
    await tester.tap(find.text('Processing details').at(1));
    await tester.pumpAndSettle();
    expect(
      find.text('Status: Destination confirmed via HTTP'),
      findsOneWidget,
    );
    expect(find.text('HTTP status: 200'), findsOneWidget);
    expect(find.text('Status: Expansion not requested'), findsNothing);
    for (final word in [
      'Safe',
      'Malicious',
      'Confirmed phishing',
    ]) {
      expect(find.textContaining(word), findsNothing);
    }
    expect(tester.takeException(), isNull);
  });
  for (final entry in {
    UrlExpansionStatus.noRedirect: 'No HTTP redirect was detected.',
    UrlExpansionStatus.timeout: 'Could not complete the check in time.',
    UrlExpansionStatus.failed: 'An error occurred while checking the link.',
    UrlExpansionStatus.blocked:
        'The check was blocked by a network security restriction.',
    UrlExpansionStatus.unsupportedPlatform:
        'URL expansion is unavailable on this platform.',
    UrlExpansionStatus.cancelled: 'The operation was cancelled.',
  }.entries) {
    testWidgets(
      'SMS ${entry.key} is brief, with technical details initially closed',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        const announced = 'https://unconfirmed.example/private';
        final unattempted = entry.key == UrlExpansionStatus.unsupportedPlatform;
        final noRedirect = entry.key == UrlExpansionStatus.noRedirect;
        final reason = switch (entry.key) {
          UrlExpansionStatus.failed => UrlExpansionFailureReason.connection,
          UrlExpansionStatus.blocked =>
            UrlExpansionFailureReason.forbiddenDestination,
          UrlExpansionStatus.unsupportedPlatform =>
            UrlExpansionFailureReason.securityPolicyUnavailable,
          _ => null,
        };
        final controlled = ControlledAnalysis();
        controlled.pending.complete(
          SmsAnalysisResult(
            originalText: 'SMS',
            urls: [
              UrlProcessingResult(
                contentRaw: 'https://bit.ly/a',
                normalizedUrl: 'https://bit.ly/a',
                isUrl: true,
                wasShortened: true,
                expansion: UrlExpansionResult(
                  status: entry.key,
                  failureReason: reason,
                  redirectCount: unattempted || noRedirect ? 0 : 1,
                  announcedDestination: unattempted || noRedirect
                      ? null
                      : announced,
                  lastHttpStatus: unattempted
                      ? null
                      : noRedirect
                      ? 200
                      : 302,
                ),
              ),
            ],
          ),
        );
        useCase = controlled;
        await open(tester);
        await analyze(tester, 'SMS');
        expect(find.text(entry.value), findsOneWidget);
        expect(find.text('Shortener detected.'), findsOneWidget);
        expect(find.text('Confirmed HTTP destination:'), findsNothing);
        expect(find.text(announced), findsNothing);
        expect(find.textContaining('Status:'), findsNothing);
        expect(find.textContaining('HTTP status:'), findsNothing);
        expect(find.textContaining('Reason:'), findsNothing);
        await tester.ensureVisible(find.text('Processing details'));
        await tester.tap(find.text('Processing details'));
        await tester.pumpAndSettle();
        expect(find.textContaining('Status:'), findsOneWidget);
        expect(
          find.textContaining('Reason:'),
          reason == null ? findsNothing : findsOneWidget,
        );
        expect(
          find.textContaining('HTTP status:'),
          unattempted ? findsNothing : findsOneWidget,
        );
        expect(find.text(announced), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final hasResult in [false, true]) {
    testWidgets(
      'SMS ${hasResult ? 'notAttempted' : 'null'} makes no expansion claim',
      (tester) async {
        final controlled = ControlledAnalysis();
        controlled.pending.complete(
          SmsAnalysisResult(
            originalText: 'SMS',
            urls: [
              UrlProcessingResult(
                contentRaw: 'https://bit.ly/a',
                normalizedUrl: 'https://bit.ly/a',
                isUrl: true,
                wasShortened: true,
                expansion: hasResult
                    ? UrlExpansionResult(
                        status: UrlExpansionStatus.notAttempted,
                      )
                    : null,
              ),
            ],
          ),
        );
        useCase = controlled;
        await open(tester);
        await analyze(tester, 'SMS');
        expect(find.text('Confirmed HTTP destination:'), findsNothing);
        expect(
          find.text('Processing details'),
          hasResult ? findsOneWidget : findsNothing,
        );
        if (hasResult) {
          await tester.ensureVisible(find.text('Processing details'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Processing details'));
          await tester.pumpAndSettle();
          expect(
            find.text('Status: Expansion not requested'),
            findsOneWidget,
          );
          expect(find.textContaining('Redirects:'), findsNothing);
        }
      },
    );
  }
  for (final mode in ['text', 'empty', 'whitespace', 'error']) {
    testWidgets('clipboard $mode preserves existing text when invalid', (
      tester,
    ) async {
      String? format;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.getData') {
              format = call.arguments as String;
              if (mode == 'error') throw PlatformException(code: 'denied');
              return mode == 'empty'
                  ? null
                  : {'text': mode == 'text' ? 'Pasted SMS' : '   '};
            }
            return null;
          });
      await open(tester);
      await tester.enterText(find.byType(TextField), 'Existing text');
      await tester.tap(find.text('Paste text'));
      await tester.pumpAndSettle();
      expect(format, Clipboard.kTextPlain);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        mode == 'text' ? 'Pasted SMS' : 'Existing text',
      );
      if (mode == 'error') {
        expect(find.text('Could not read clipboard.'), findsOneWidget);
      }
      if (mode == 'empty' || mode == 'whitespace') {
        expect(find.text('Clipboard does not contain text.'), findsOneWidget);
      }
    });
  }
  testWidgets('loading, failure, reset and successful retry', (tester) async {
    final controlled = ControlledAnalysis();
    useCase = controlled;
    await open(tester);
    await tester.enterText(find.byType(TextField), 'message');
    await tester.tap(find.text('Analyze links'));
    await tester.pump();
    expect(
      tester.element(find.byType(SmishingScreen)).read<SmishingBloc>().state,
      isA<SmishingLoading>(),
    );
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    controlled.pending.completeError(Exception('private detail'));
    await tester.pumpAndSettle();
    expect(
      find.text('Could not analyze the SMS. Please try again.'),
      findsOneWidget,
    );
    expect(find.textContaining('private detail'), findsNothing);
    await tester.tap(find.text('Analyze another SMS'));
    await tester.pumpAndSettle();
    expect(
      find.text('Could not analyze the SMS. Please try again.'),
      findsNothing,
    );
  });
  testWidgets('loading to success and long content on narrow screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controlled = ControlledAnalysis();
    useCase = controlled;
    await open(tester);
    final url = 'https://example.com/${'a' * 800}';
    await tester.enterText(find.byType(TextField), '${'message ' * 200}$url');
    await tester.ensureVisible(find.text('Analyze links'));
    await tester.tap(find.text('Analyze links'));
    await tester.pump();
    expect(
      tester.element(find.byType(SmishingScreen)).read<SmishingBloc>().state,
      isA<SmishingLoading>(),
    );
    controlled.pending.complete(
      SmsAnalysisResult(
        originalText: url,
        urls: [
          UrlProcessingResult(
            contentRaw: url,
            normalizedUrl: url,
            isUrl: true,
            wasShortened: false,
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    await tester.dragFrom(const Offset(160, 580), const Offset(0, -250));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Link 1'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Link 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Messages opens a route with its own bloc and returns to Home', (
    tester,
  ) async {
    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<AnalyzeSmsUseCase>.value(value: useCase),
          RepositoryProvider<GetProfileUseCase>.value(
            value: FakeProfileUseCase(),
          ),
          RepositoryProvider<SignOutUseCase>.value(value: FakeSignOut()),
        ],
        child: MaterialApp(
          theme: buildTheme(),
          home: HomeScreen(
            initialProfile: Profile(
              id: '1',
              name: 'Ana',
              lastName: 'Perez',
              email: 'ana@example.com',
              active: true,
              createdIn: DateTime(2026),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Messages'));
    await tester.pumpAndSettle();
    expect(find.byType(SmishingScreen), findsOneWidget);
    await analyze(tester, 'https://example.com');
    expect(find.text('Detected links: 1'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(SmishingScreen), findsNothing);
    await tester.tap(find.text('Messages'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
  });
}
