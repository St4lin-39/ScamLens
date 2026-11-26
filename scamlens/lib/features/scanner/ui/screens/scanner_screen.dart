import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:scamlens/components/error_message.dart';
import 'package:scamlens/components/primary_button.dart';
import 'package:scamlens/components/scamlens_header.dart';
import 'package:scamlens/components/url_expansion_details.dart';
import 'package:scamlens/features/scanner/ui/bloc/scanner_bloc.dart';
import 'package:scamlens/theme/app_theme.dart';
import 'package:scamlens/components/risk_traffic_light.dart';
import 'package:scamlens/components/analysis_progress_view.dart';
import 'package:scamlens/components/ioc_threat_banner.dart';

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
      appBar: AppBar(title: const Text('Secure QR Scanner')),
      body: SafeArea(
        child: BlocConsumer<ScannerBloc, ScannerState>(
          listener: (context, state) {
            // BLoC manages state without abruptly pausing camera hardware
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
              'Camera permission required',
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
                'ScamLens needs camera access to scan and analyze QR codes in real time.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 200,
              child: PrimaryButton(
                label: 'Grant Permission',
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
                    debugPrint(
                      '[SCAMLENS UI] QR code detected by camera: $raw',
                    );
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

            const Positioned(
              bottom: 24,
              child: IgnorePointer(
                child: Text(
                  'POINT CAMERA AT QR CODE',
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
                    'Real-time scanner active',
                    style: TextStyle(
                      color: AppColors.accentCyan,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Focus on a physical QR code to intercept its content before your browser opens it.',
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
                  'Simulate QR scan (Shortener test)',
                  style: TextStyle(fontSize: 12),
                ),
                onPressed: () {
                  context.read<ScannerBloc>().add(
                    QRCodeScannedEvent(
                      rawValue: 'https://tinyurl.com/2p9cbe4r',
                    ),
                  );
                },
              ),
            ],

            if (state is ScannerProcessingState) ...[
              AnalysisProgressView(progress: state.progress),
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
                    state.isUrl ? 'INTERCEPTED LINK' : 'DETECTED TEXT',
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
                            'SHORTENER DETECTED',
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
                      'Detected QR content:',
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
                        'Normalized URL:',
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
                    if (state.result.expansion?.verifiedDestination
                        case final destination?) ...[
                      const SizedBox(height: 8),
                      const Text(
                        'Confirmed HTTP destination:',
                        style: TextStyle(
                          color: AppColors.accentCyan,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      SelectableText(
                        destination,
                        style: const TextStyle(
                          color: AppColors.accentCyan,
                          fontSize: 13,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                    if (state.isUrl)
                      IocThreatBanner(iocCheck: state.result.iocCheck),
                    if (state.isUrl)
                      RiskTrafficLight(evaluation: state.riskEvaluation),
                    if (state.isUrl)
                      UrlExpansionDetails(expansion: state.result.expansion),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              AnalysisProgressView(progress: state.progress, running: false),
              PrimaryButton(
                label: 'Scan another QR',
                onPressed: () {
                  context.read<ScannerBloc>().add(ResetScannerEvent());
                },
              ),
            ],

            if (state is ScannerErrorState) ...[
              ErrorMessage(message: state.errorMessage),
              AnalysisProgressView(progress: state.progress, running: false),
              const SizedBox(height: 12),
              PrimaryButton(
                label: 'Retry',
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
