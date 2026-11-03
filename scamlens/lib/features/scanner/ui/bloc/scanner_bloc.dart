import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smart_permission/smart_permission.dart';
import 'package:permission_handler/permission_handler.dart';

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
  final String contentRaw;
  final bool isUrl;
  ScannerSuccessState({required this.contentRaw, required this.isUrl});
}

class ScannerErrorState extends ScannerState {
  final String errorMessage;
  ScannerErrorState({required this.errorMessage});
}

class ScannerBloc extends Bloc<ScannerEvent, ScannerState> {
  ScannerBloc() : super(ScannerInitialState()) {
    on<CheckCameraPermissionEvent>(_onCheckCameraPermission);
    on<RequestCameraPermissionEvent>(_onRequestCameraPermission);
    on<QRCodeScannedEvent>(_onQRCodeScanned);
    on<ResetScannerEvent>((event, emit) => emit(ScannerActiveState()));
  }
  Future<void> _onCheckCameraPermission(
    CheckCameraPermissionEvent event,
    Emitter<ScannerState> emit,
  ) async {
    final hasPermission = await SmartPermission.hasPermission(
      Permission.camera,
    );
    if (hasPermission) {
      emit(ScannerActiveState());
    } else {
      emit(ScannerPermissionRequiredState());
    }
  }

  Future<void> _onRequestCameraPermission(
    RequestCameraPermissionEvent event,
    Emitter<ScannerState> emit,
  ) async {
    final status = await Permission.camera.request();
    if (status.isGranted) {
      emit(ScannerActiveState());
    } else {
      emit(ScannerPermissionRequiredState());
    }
  }

  Future<void> _onQRCodeScanned(
    QRCodeScannedEvent event,
    Emitter<ScannerState> emit,
  ) async {
    emit(ScannerProcessingState());

    final raw = event.rawValue.trim();
    if (raw.isEmpty) {
      emit(ScannerErrorState(errorMessage: 'Código QR vacío o ilegible'));
      return;
    }

    final uri = Uri.tryParse(raw);
    final isUrl =
        uri != null &&
        (uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https') ||
            raw.toLowerCase().startsWith('www.'));

    emit(ScannerSuccessState(contentRaw: raw, isUrl: isUrl));
  }
}
