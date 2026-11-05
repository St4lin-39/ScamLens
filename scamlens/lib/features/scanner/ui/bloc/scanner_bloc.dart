import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:scamlens/core/services/url_service.dart';
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
  final String contentRaw;
  final String normalizedUrl;
  final bool isUrl;
  final bool wasShortened;

  ScannerSuccessState({
    required this.contentRaw,
    required this.normalizedUrl,
    required this.isUrl,
    required this.wasShortened,
  });
}

class ScannerErrorState extends ScannerState {
  final String errorMessage;
  ScannerErrorState({required this.errorMessage});
}

class ScannerBloc extends Bloc<ScannerEvent, ScannerState> {
  final UrlService _urlService;

  ScannerBloc({UrlService? urlService})
      : _urlService = urlService ?? UrlServiceImpl(),
        super(ScannerInitialState()) {
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

      final uri = Uri.tryParse(raw);
      final isUrl = uri != null &&
          ((uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https')) ||
              raw.toLowerCase().startsWith('www.'));

      String normalizedUrl = raw;
      bool wasShortened = false;

      if (isUrl) {
        try {
          // 1. Normalización inicial
          final initialNormalized = _urlService.normalizeUrl(raw);

          // 2. Comprobar si proviene de un acortador conocido
          wasShortened = _urlService.isShortenedUrl(initialNormalized);

          // 3. Desacortar siguiendo cabeceras HTTP con timeout seguro
          if (wasShortened) {
            normalizedUrl = await _urlService
                .unshortenUrl(initialNormalized)
                .timeout(
                  const Duration(seconds: 3),
                  onTimeout: () => initialNormalized,
                );
          } else {
            normalizedUrl = initialNormalized;
          }
        } catch (_) {
          normalizedUrl = raw;
        }
      }

      emit(ScannerSuccessState(
        contentRaw: raw,
        normalizedUrl: normalizedUrl,
        isUrl: isUrl,
        wasShortened: wasShortened,
      ));
    } catch (e) {
      emit(ScannerErrorState(errorMessage: 'Error al procesar: $e'));
    }
  }
}
