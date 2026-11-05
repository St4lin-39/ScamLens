import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:scamlens/components/error_message.dart';
import 'package:scamlens/components/primary_button.dart';
import 'package:scamlens/components/scamlens_header.dart';
import 'package:scamlens/features/scanner/ui/bloc/scanner_bloc.dart';
import 'package:scamlens/theme/app_theme.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  MobileScannerController? _cameraController;

  @override
  void initState() {
    super.initState();
    _cameraController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      detectionTimeoutMs: 500,
    );
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Escáner QR Seguro')),
      body: SafeArea(
        child: BlocConsumer<ScannerBloc, ScannerState>(
          listener: (context, state) {
            // El BLoC gestiona el estado sin pausar bruscamente el hardware de video
          },
          builder: (context, state) {
            return Column(
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: ScamLensHeader(showProtectedBadge: true),
                ),
                Expanded(flex: 3, child: _buildViewfinder(context, state)),
                Expanded(flex: 2, child: _buildResultCard(context, state)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildViewfinder(BuildContext context, ScannerState state) {
    if (state is ScannerPermissionRequiredState) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.videocam_off_outlined,
              size: 64,
              color: AppColors.error,
            ),
            const SizedBox(height: 12),
            const Text(
              'Permiso de cámara requerido',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'ScamLens necesita acceso a la cámara para escanear y analizar códigos QR en tiempo real.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 200,
              child: PrimaryButton(
                label: 'Conceder Permiso',
                onPressed: () {
                  context.read<ScannerBloc>().add(
                    RequestCameraPermissionEvent(),
                  );
                },
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          alignment: Alignment.center,
          children: [
            MobileScanner(
              controller: _cameraController,
              onDetect: (capture) {
                for (final barcode in capture.barcodes) {
                  final raw = barcode.rawValue ?? barcode.displayValue;
                  if (raw != null && raw.trim().isNotEmpty) {
                    debugPrint('[SCAMLENS UI] Código detectado por cámara: $raw');
                    context.read<ScannerBloc>().add(
                          QRCodeScannedEvent(rawValue: raw),
                        );
                    break;
                  }
                }
              },
            ),

            IgnorePointer(
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: AppColors.accentCyan.withValues(alpha: 0.6),
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),

            const IgnorePointer(
              child: Positioned(
                bottom: 24,
                child: Text(
                  'APUNTA LA CÁMARA AL QR',
                  style: TextStyle(
                    color: AppColors.accentCyan,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard(BuildContext context, ScannerState state) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (state is ScannerActiveState) ...[
              const Row(
                children: [
                  Icon(
                    Icons.radar_rounded,
                    color: AppColors.accentCyan,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Escáner activo en tiempo real',
                    style: TextStyle(
                      color: AppColors.accentCyan,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Enfoca un código QR físico para interceptar su contenido antes de que el navegador lo abra.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.accentCyan,
                  side: const BorderSide(color: AppColors.border),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.qr_code_2_rounded, size: 18),
                label: const Text(
                  'Simular lectura de QR (Prueba acortador)',
                  style: TextStyle(fontSize: 12),
                ),
                onPressed: () {
                  context.read<ScannerBloc>().add(
                    QRCodeScannedEvent(rawValue: 'https://tinyurl.com/2p9cbe4r'),
                  );
                },
              ),
            ],

            if (state is ScannerProcessingState) ...[
              const Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(color: AppColors.accentCyan),
                    SizedBox(height: 12),
                    Text(
                      'Interceptando y desacortando enlace...',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],

            if (state is ScannerSuccessState) ...[
              Row(
                children: [
                  Icon(
                    state.isUrl
                        ? Icons.link_rounded
                        : Icons.text_snippet_outlined,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    state.isUrl ? 'ENLACE INTERCEPTADO' : 'TEXTO DETECTADO',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const Spacer(),
                  if (state.wasShortened)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.warningYellow.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.warningYellow),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            size: 12,
                            color: AppColors.warningYellow,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'ACORTADOR DETECTADO',
                            style: TextStyle(
                              color: AppColors.warningYellow,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Contenido detectado en QR:',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 4),
                    SelectableText(
                      state.contentRaw,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontFamily: 'monospace',
                      ),
                    ),
                    if (state.wasShortened) ...[
                      const Divider(height: 18, color: AppColors.border),
                      const Text(
                        'Destino real desenmascarado:',
                        style: TextStyle(
                          color: AppColors.accentCyan,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      SelectableText(
                        state.normalizedUrl,
                        style: const TextStyle(
                          color: AppColors.accentCyan,
                          fontSize: 13,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              PrimaryButton(
                label: 'Escanear otro QR',
                onPressed: () {
                  context.read<ScannerBloc>().add(ResetScannerEvent());
                },
              ),
            ],

            if (state is ScannerErrorState) ...[
              ErrorMessage(message: state.errorMessage),
              const SizedBox(height: 12),
              PrimaryButton(
                label: 'Reintentar',
                onPressed: () {
                  context.read<ScannerBloc>().add(ResetScannerEvent());
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
