import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:scamlens/features/smishing/domain/entities/sms_analysis_result.dart';
import 'package:scamlens/features/smishing/domain/usecases/analyze_sms_usecase.dart';

abstract class SmishingEvent {}

class AnalyzeSmsEvent extends SmishingEvent {
  final String text;

  AnalyzeSmsEvent({required this.text});
}

class ResetSmishingEvent extends SmishingEvent {}

abstract class SmishingState {}

class SmishingInitial extends SmishingState {}

class SmishingLoading extends SmishingState {}

class SmishingSuccess extends SmishingState {
  final SmsAnalysisResult result;

  SmishingSuccess({required this.result});
}

class SmishingError extends SmishingState {
  final String errorMessage;

  SmishingError({required this.errorMessage});
}

class SmishingBloc extends Bloc<SmishingEvent, SmishingState> {
  final AnalyzeSmsUseCase analyzeSmsUseCase;
  final _inFlight = <String, Future<SmsAnalysisResult>>{};
  int _revision = 0;
  String? _activeText;

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
    if (_activeText == event.text) return;

    final revision = ++_revision;
    _activeText = event.text;
    emit(SmishingLoading());

    // Reuse pending work even for A -> B -> A or Reset -> A.
    // Domain work is not cancelled; only the latest request may publish it.
    final pending = _inFlight.putIfAbsent(
      event.text,
      () => Future<SmsAnalysisResult>.sync(() => analyzeSmsUseCase(event.text)),
    );
    bool isCurrent() => revision == _revision && !emit.isDone;

    try {
      final result = await pending;
      if (isCurrent()) emit(SmishingSuccess(result: result));
    } on ArgumentError {
      if (isCurrent()) {
        emit(
          SmishingError(
            errorMessage: 'Ingresa un SMS con texto para analizar.',
          ),
        );
      }
    } catch (_) {
      if (isCurrent()) {
        emit(
          SmishingError(
            errorMessage: 'No se pudo analizar el SMS. Intenta de nuevo.',
          ),
        );
      }
    } finally {
      if (identical(_inFlight[event.text], pending)) {
        _inFlight.remove(event.text);
      }
      if (revision == _revision) _activeText = null;
    }
  }
}
