import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:scamlens/shared/url_processing/domain/usecases/process_url_usecase.dart';
import 'package:scamlens/shared/url_processing/domain/entities/url_processing_result.dart';
import 'package:smart_permission/smart_permission.dart';
import 'package:scamlens/shared/url_risk/domain/entities/risk_evaluation_result.dart';
import 'package:scamlens/shared/url_risk/domain/usecases/evaluate_url_risk_usecase.dart';

import '../../../../shared/analysis_progress/domain/analysis_progress.dart';
import '../../../../shared/analysis_progress/presentation/analysis_job.dart';

abstract class ScannerEvent {}

class CheckCameraPermissionEvent extends ScannerEvent {}

class RequestCameraPermissionEvent extends ScannerEvent {}

class QRCodeScannedEvent extends ScannerEvent {
  final String rawValue;
  QRCodeScannedEvent({required this.rawValue});
}

class ResetScannerEvent extends ScannerEvent {}

abstract class ScannerState {}

class ScannerInitialState extends ScannerState {}

class ScannerPermissionRequiredState extends ScannerState {}

class ScannerActiveState extends ScannerState {}

class ScannerProcessingState extends ScannerState {
  final AnalysisProgressSnapshot progress;
  ScannerProcessingState({
    this.progress = const AnalysisProgressSnapshot.empty(),
  });
}

class ScannerSuccessState extends ScannerState {
  final UrlProcessingResult result;
  final RiskEvaluationResult riskEvaluation;
  final AnalysisProgressSnapshot progress;

  String get contentRaw => result.contentRaw;
  String get normalizedUrl => result.normalizedUrl;
  bool get isUrl => result.isUrl;
  bool get wasShortened => result.wasShortened;

  ScannerSuccessState({
    required this.result,
    RiskEvaluationResult? riskEvaluation,
    this.progress = const AnalysisProgressSnapshot.empty(),
  }) : riskEvaluation =
           riskEvaluation ??
           RiskEvaluationResult.notEvaluated(result.contentRaw);
}

class ScannerErrorState extends ScannerState {
  final AnalysisProgressSnapshot progress;
  final String errorMessage;
  ScannerErrorState({
    required this.errorMessage,
    this.progress = const AnalysisProgressSnapshot.empty(),
  });
}

class ScannerBloc extends Bloc<ScannerEvent, ScannerState> {
  final ProcessUrlUseCase processUrlUseCase;
  final EvaluateUrlRiskUseCase _evaluateUrlRiskUseCase;
  final _inFlight = <String, AnalysisJob<ScannerSuccessState>>{};
  int _revision = 0;
  String? _activeRaw;
  bool _closing = false;

  ScannerBloc({
    required this.processUrlUseCase,
    EvaluateUrlRiskUseCase? evaluateUrlRiskUseCase,
  }) : _evaluateUrlRiskUseCase =
           evaluateUrlRiskUseCase ?? EvaluateUrlRiskUseCase(),
       super(ScannerInitialState()) {
    on<CheckCameraPermissionEvent>(_onCheckCameraPermission);
    on<RequestCameraPermissionEvent>(_onRequestCameraPermission);
    on<QRCodeScannedEvent>(_onQRCodeScanned);
    on<ResetScannerEvent>((event, emit) {
      _revision++;
      _activeRaw = null;
      emit(ScannerActiveState());
    });
  }

  Future<void> _onCheckCameraPermission(
    CheckCameraPermissionEvent event,
    Emitter<ScannerState> emit,
  ) async {
    if (_closing) return;
    final revision = _revision;
    bool isCurrent() => !_closing && revision == _revision && !emit.isDone;
    if (kIsWeb) {
      emit(ScannerActiveState());
      return;
    }

    try {
      final hasPermission = await SmartPermission.hasPermission(
        Permission.camera,
      );
      if (!isCurrent()) return;
      if (hasPermission) {
        emit(ScannerActiveState());
      } else {
        emit(ScannerPermissionRequiredState());
      }
    } catch (_) {
      if (isCurrent()) emit(ScannerActiveState());
    }
  }

  Future<void> _onRequestCameraPermission(
    RequestCameraPermissionEvent event,
    Emitter<ScannerState> emit,
  ) async {
    if (_closing) return;
    final revision = _revision;
    bool isCurrent() => !_closing && revision == _revision && !emit.isDone;
    if (kIsWeb) {
      emit(ScannerActiveState());
      return;
    }

    try {
      final status = await Permission.camera.request();
      if (!isCurrent()) return;
      if (status.isGranted) {
        emit(ScannerActiveState());
      } else {
        emit(ScannerPermissionRequiredState());
      }
    } catch (_) {
      if (isCurrent()) emit(ScannerActiveState());
    }
  }

  Future<void> _onQRCodeScanned(
    QRCodeScannedEvent event,
    Emitter<ScannerState> emit,
  ) async {
    final raw = event.rawValue.trim();
    if (_closing ||
        _activeRaw == raw ||
        state is ScannerProcessingState ||
        state is ScannerSuccessState) {
      return;
    }
    final revision = ++_revision;
    _activeRaw = raw;
    emit(ScannerProcessingState());
    AnalysisJob<ScannerSuccessState>? job;
    void progress(AnalysisProgressSnapshot snapshot) {
      if (!_closing && revision == _revision && !emit.isDone) {
        emit(ScannerProcessingState(progress: snapshot));
      }
    }

    try {
      if (raw.isEmpty) {
        emit(ScannerErrorState(errorMessage: 'Empty or unreadable QR code'));
        return;
      }

      job = _inFlight.putIfAbsent(
        raw,
        () => AnalysisJob((report) async {
          final result = await processUrlUseCase(raw, onProgress: report);
          final risk = _evaluateUrlRiskUseCase(result, onProgress: report);
          report(
            const AnalysisProgress(
              AnalysisStage.prepareResult,
              AnalysisStageStatus.active,
            ),
          );
          try {
            final success = ScannerSuccessState(
              result: result,
              riskEvaluation: risk,
            );
            report(
              const AnalysisProgress(
                AnalysisStage.prepareResult,
                AnalysisStageStatus.completed,
              ),
            );
            return success;
          } catch (_) {
            report(
              const AnalysisProgress(
                AnalysisStage.prepareResult,
                AnalysisStageStatus.failed,
                reason: AnalysisProgressReason.error,
              ),
            );
            rethrow;
          }
        }),
      );
      job.observe(progress);
      final result = await job.future;
      if (!_closing && revision == _revision && !emit.isDone) {
        emit(
          ScannerSuccessState(
            result: result.result,
            riskEvaluation: result.riskEvaluation,
            progress: job.snapshot,
          ),
        );
      }
    } catch (e) {
      if (!_closing && revision == _revision && !emit.isDone) {
        emit(
          ScannerErrorState(
            errorMessage: 'Processing error: $e',
            progress: job?.snapshot ?? const AnalysisProgressSnapshot.empty(),
          ),
        );
      }
    } finally {
      job?.detach(progress);
      if (identical(_inFlight[raw], job)) _inFlight.remove(raw);
      if (revision == _revision) _activeRaw = null;
    }
  }

  @override
  Future<void> close() {
    _closing = true;
    _revision++;
    for (final job in _inFlight.values) {
      job.dispose();
    }
    _inFlight.clear();
    return super.close();
  }
}
