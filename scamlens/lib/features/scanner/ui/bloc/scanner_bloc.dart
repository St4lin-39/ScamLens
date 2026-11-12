import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:scamlens/shared/url_processing/domain/usecases/process_url_usecase.dart';
import 'package:scamlens/shared/url_processing/domain/entities/url_processing_result.dart';
import 'package:smart_permission/smart_permission.dart';

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

class ScannerProcessingState extends ScannerState {}

class ScannerSuccessState extends ScannerState {
  final UrlProcessingResult result;

  String get contentRaw => result.contentRaw;
  String get normalizedUrl => result.normalizedUrl;
  bool get isUrl => result.isUrl;
  bool get wasShortened => result.wasShortened;

  ScannerSuccessState({required this.result});
}

class ScannerErrorState extends ScannerState {
  final String errorMessage;
  ScannerErrorState({required this.errorMessage});
}

class ScannerBloc extends Bloc<ScannerEvent, ScannerState> {
  final ProcessUrlUseCase processUrlUseCase;

  ScannerBloc({required this.processUrlUseCase})
    : super(ScannerInitialState()) {
    on<CheckCameraPermissionEvent>(_onCheckCameraPermission);
    on<RequestCameraPermissionEvent>(_onRequestCameraPermission);
    on<QRCodeScannedEvent>(_onQRCodeScanned);
    on<ResetScannerEvent>((event, emit) => emit(ScannerActiveState()));
  }

  Future<void> _onCheckCameraPermission(
    CheckCameraPermissionEvent event,
    Emitter<ScannerState> emit,
  ) async {
    if (kIsWeb) {
      emit(ScannerActiveState());
      return;
    }

    try {
      final hasPermission = await SmartPermission.hasPermission(
        Permission.camera,
      );
      if (hasPermission) {
        emit(ScannerActiveState());
      } else {
        emit(ScannerPermissionRequiredState());
      }
    } catch (_) {
      emit(ScannerActiveState());
    }
  }

  Future<void> _onRequestCameraPermission(
    RequestCameraPermissionEvent event,
    Emitter<ScannerState> emit,
  ) async {
    if (kIsWeb) {
      emit(ScannerActiveState());
      return;
    }

    try {
      final status = await Permission.camera.request();
      if (status.isGranted) {
        emit(ScannerActiveState());
      } else {
        emit(ScannerPermissionRequiredState());
      }
    } catch (_) {
      emit(ScannerActiveState());
    }
  }

  Future<void> _onQRCodeScanned(
    QRCodeScannedEvent event,
    Emitter<ScannerState> emit,
  ) async {
    // Si ya estamos procesando o mostrando éxito, no duplicar
    if (state is ScannerProcessingState || state is ScannerSuccessState) {
      return;
    }

    emit(ScannerProcessingState());

    try {
      final raw = event.rawValue.trim();
      if (raw.isEmpty) {
        emit(ScannerErrorState(errorMessage: 'Código QR vacío o ilegible'));
        return;
      }

      final result = await processUrlUseCase(raw);

      emit(ScannerSuccessState(result: result));
    } catch (e) {
      emit(ScannerErrorState(errorMessage: 'Error al procesar: $e'));
    }
  }
}
