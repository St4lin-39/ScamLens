import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:scamlens/features/smishing/domain/entities/sms_analysis_result.dart';
import 'package:scamlens/features/smishing/domain/usecases/analyze_sms_usecase.dart';

import '../../../../shared/analysis_progress/domain/analysis_progress.dart';
import '../../../../shared/analysis_progress/presentation/analysis_job.dart';

abstract class SmishingEvent {}

class AnalyzeSmsEvent extends SmishingEvent {
  final String text;

  AnalyzeSmsEvent({required this.text});
}

class ResetSmishingEvent extends SmishingEvent {}

abstract class SmishingState {}

class SmishingInitial extends SmishingState {}

class SmishingLoading extends SmishingState {
  final AnalysisProgressSnapshot progress;
  SmishingLoading({this.progress = const AnalysisProgressSnapshot.empty()});
}

class SmishingSuccess extends SmishingState {
  final SmsAnalysisResult result;
  final AnalysisProgressSnapshot progress;

  SmishingSuccess({
    required this.result,
    this.progress = const AnalysisProgressSnapshot.empty(),
  });
}

class SmishingError extends SmishingState {
  final String errorMessage;
  final AnalysisProgressSnapshot progress;

  SmishingError({
    required this.errorMessage,
    this.progress = const AnalysisProgressSnapshot.empty(),
  });
}

class SmishingBloc extends Bloc<SmishingEvent, SmishingState> {
  final AnalyzeSmsUseCase analyzeSmsUseCase;
  final _inFlight = <String, AnalysisJob<SmsAnalysisResult>>{};
  int _revision = 0;
  String? _activeText;
  bool _closing = false;

  SmishingBloc({required this.analyzeSmsUseCase}) : super(SmishingInitial()) {
    on<AnalyzeSmsEvent>(_onAnalyzeSms);
    on<ResetSmishingEvent>((event, emit) {
      _revision++;
      _activeText = null;
      emit(SmishingInitial());
    });
  }

  Future<void> _onAnalyzeSms(
    AnalyzeSmsEvent event,
    Emitter<SmishingState> emit,
  ) async {
    if (_closing || _activeText == event.text) return;

    final revision = ++_revision;
    _activeText = event.text;
    emit(SmishingLoading());

    // Reuse pending work even for A -> B -> A or Reset -> A.
    // Domain work is not cancelled; only the latest request may publish it.
    final pending = _inFlight.putIfAbsent(
      event.text,
      () => AnalysisJob(
        (report) => analyzeSmsUseCase(event.text, onProgress: report),
      ),
    );
    bool isCurrent() => !_closing && revision == _revision && !emit.isDone;
    void progress(AnalysisProgressSnapshot snapshot) {
      if (isCurrent()) emit(SmishingLoading(progress: snapshot));
    }

    pending.observe(progress);

    try {
      final result = await pending.future;
      if (isCurrent()) {
        emit(SmishingSuccess(result: result, progress: pending.snapshot));
      }
    } on ArgumentError {
      if (isCurrent()) {
        emit(
          SmishingError(
            errorMessage: 'Enter an SMS message to analyze.',
            progress: pending.snapshot,
          ),
        );
      }
    } catch (_) {
      if (isCurrent()) {
        emit(
          SmishingError(
            errorMessage: 'Could not analyze the SMS. Please try again.',
            progress: pending.snapshot,
          ),
        );
      }
    } finally {
      pending.detach(progress);
      if (identical(_inFlight[event.text], pending)) {
        _inFlight.remove(event.text);
      }
      if (revision == _revision) _activeText = null;
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
