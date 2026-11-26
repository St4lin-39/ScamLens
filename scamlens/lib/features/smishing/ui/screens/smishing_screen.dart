import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:scamlens/components/url_expansion_details.dart';
import 'package:scamlens/features/smishing/ui/bloc/smishing_bloc.dart';
import 'package:scamlens/theme/app_theme.dart';
import 'package:scamlens/components/risk_traffic_light.dart';
import 'package:scamlens/components/analysis_progress_view.dart';

class SmishingScreen extends StatefulWidget {
  const SmishingScreen({super.key});

  @override
  State<SmishingScreen> createState() => _SmishingScreenState();
}

class _SmishingScreenState extends State<SmishingScreen> {
  final _controller = TextEditingController();
  String? _inputError;
  bool _pasting = false;
  int _editRevision = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final revision = _editRevision;
    setState(() => _pasting = true);
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (!mounted || revision != _editRevision) return;
      final text = data?.text;
      if (text == null || text.trim().isEmpty) {
        setState(() => _inputError = 'Clipboard does not contain text.');
      } else {
        _controller.text = text;
        _editRevision++;
        setState(() => _inputError = null);
        context.read<SmishingBloc>().add(ResetSmishingEvent());
      }
    } catch (_) {
      if (mounted && revision == _editRevision) {
        setState(() => _inputError = 'Could not read clipboard.');
      }
    } finally {
      if (mounted) setState(() => _pasting = false);
    }
  }

  void _reset() {
    _controller.clear();
    _editRevision++;
    setState(() => _inputError = null);
    context.read<SmishingBloc>().add(ResetSmishingEvent());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SMS Links')),
      body: SafeArea(
        child: BlocBuilder<SmishingBloc, SmishingState>(
          builder: (context, state) {
            final loading = state is SmishingLoading;
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const Icon(
                  Icons.sms_outlined,
                  color: AppColors.accentCyan,
                  size: 40,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Extracts and evaluates links from an SMS using local risk signals. '
                  'Message content is not evaluated and link safety is not guaranteed.',
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _controller,
                  enabled: !loading,
                  minLines: 4,
                  maxLines: 8,
                  keyboardType: TextInputType.multiline,
                  decoration: InputDecoration(
                    labelText: 'SMS message',
                    alignLabelWithHint: true,
                    hintText: 'Type or paste the message here',
                    errorText: _inputError,
                    errorMaxLines: 3,
                  ),
                  onChanged: (_) {
                    _editRevision++;
                    setState(() => _inputError = null);
                    context.read<SmishingBloc>().add(ResetSmishingEvent());
                  },
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: loading || _pasting ? null : _paste,
                  icon: const Icon(Icons.content_paste),
                  label: const Text('Paste text'),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: loading || _pasting
                      ? null
                      : () {
                          if (_controller.text.trim().isEmpty) {
                            setState(
                              () => _inputError =
                                  'Enter an SMS message to analyze.',
                            );
                            return;
                          }
                          FocusScope.of(context).unfocus();
                          context.read<SmishingBloc>().add(
                            AnalyzeSmsEvent(text: _controller.text),
                          );
                        },
                  child: const Text('Analyze links'),
                ),
                if (state is SmishingLoading) ...[
                  const SizedBox(height: 24),
                  AnalysisProgressView(progress: state.progress),
                ],
                if (state is SmishingError) ...[
                  const SizedBox(height: 20),
                  Text(
                    state.errorMessage,
                    style: const TextStyle(color: AppColors.error),
                  ),
                  AnalysisProgressView(
                    progress: state.progress,
                    running: false,
                  ),
                ],
                if (state is SmishingSuccess) ...[
                  const SizedBox(height: 20),
                  Text(
                    state.result.urls.isEmpty
                        ? 'No links were found in this SMS.'
                        : 'Detected links: ${state.result.urls.length}',
                  ),
                  for (final (index, url) in state.result.urls.indexed)
                    Card(
                      margin: const EdgeInsets.only(top: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Link ${index + 1}',
                              style: const TextStyle(color: AppColors.primary),
                            ),
                            const SizedBox(height: 8),
                            const Text('Detected:'),
                            SelectableText(url.contentRaw),
                            const SizedBox(height: 8),
                            const Text('Normalized URL:'),
                            SelectableText(url.normalizedUrl),
                            if (url.wasShortened) ...[
                              const SizedBox(height: 8),
                              const Text('Shortener detected.'),
                            ],
                            if (url.expansion?.verifiedDestination
                                case final destination?) ...[
                              const SizedBox(height: 8),
                              const Text('Confirmed HTTP destination:'),
                              SelectableText(destination),
                            ],
                            RiskTrafficLight(
                              evaluation: state.result.riskEvaluations[index],
                            ),

                            UrlExpansionDetails(expansion: url.expansion),
                          ],
                        ),
                      ),
                    ),
                ],
                if (state is SmishingSuccess)
                  AnalysisProgressView(
                    progress: state.progress,
                    running: false,
                  ),
                if (state is! SmishingInitial)
                  TextButton(
                    onPressed: _reset,
                    child: const Text('Analyze another SMS'),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
