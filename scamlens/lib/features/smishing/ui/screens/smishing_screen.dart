import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:scamlens/components/url_expansion_details.dart';
import 'package:scamlens/features/smishing/ui/bloc/smishing_bloc.dart';
import 'package:scamlens/theme/app_theme.dart';

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
        setState(() => _inputError = 'El portapapeles no contiene texto.');
      } else {
        _controller.text = text;
        _editRevision++;
        setState(() => _inputError = null);
        context.read<SmishingBloc>().add(ResetSmishingEvent());
      }
    } catch (_) {
      if (mounted && revision == _editRevision) {
        setState(() => _inputError = 'No se pudo leer el portapapeles.');
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
      appBar: AppBar(title: const Text('Enlaces en SMS')),
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
                  'Extrae, normaliza y consulta la expansión de los enlaces de un SMS. '
                  'No se evalúa el contenido del mensaje ni la seguridad de los enlaces.',
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _controller,
                  enabled: !loading,
                  minLines: 4,
                  maxLines: 8,
                  keyboardType: TextInputType.multiline,
                  decoration: InputDecoration(
                    labelText: 'Mensaje SMS',
                    alignLabelWithHint: true,
                    hintText: 'Escribe o pega el mensaje aquí',
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
                  label: const Text('Pegar texto'),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: loading || _pasting
                      ? null
                      : () {
                          if (_controller.text.trim().isEmpty) {
                            setState(
                              () => _inputError =
                                  'Ingresa un SMS con texto para analizar.',
                            );
                            return;
                          }
                          FocusScope.of(context).unfocus();
                          context.read<SmishingBloc>().add(
                            AnalyzeSmsEvent(text: _controller.text),
                          );
                        },
                  child: const Text('Analizar enlaces'),
                ),
                if (loading) ...[
                  const SizedBox(height: 24),
                  const Center(child: CircularProgressIndicator()),
                  const SizedBox(height: 12),
                  const Text(
                    'Procesando enlaces...',
                    textAlign: TextAlign.center,
                  ),
                ],
                if (state is SmishingError) ...[
                  const SizedBox(height: 20),
                  Text(
                    state.errorMessage,
                    style: const TextStyle(color: AppColors.error),
                  ),
                ],
                if (state is SmishingSuccess) ...[
                  const SizedBox(height: 20),
                  Text(
                    state.result.urls.isEmpty
                        ? 'No se encontraron enlaces en este SMS.'
                        : 'Enlaces detectados: ${state.result.urls.length}',
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
                              'Enlace ${index + 1}',
                              style: const TextStyle(color: AppColors.primary),
                            ),
                            const SizedBox(height: 8),
                            const Text('Detectado:'),
                            SelectableText(url.contentRaw),
                            const SizedBox(height: 8),
                            const Text('URL normalizada:'),
                            SelectableText(url.normalizedUrl),
                            if (url.wasShortened) ...[
                              const SizedBox(height: 8),
                              const Text('Acortador detectado.'),
                            ],
                            if (url.expansion?.verifiedDestination
                                case final destination?) ...[
                              const SizedBox(height: 8),
                              const Text('Destino HTTP confirmado:'),
                              SelectableText(destination),
                            ],
                            UrlExpansionDetails(expansion: url.expansion),
                          ],
                        ),
                      ),
                    ),
                ],
                if (state is! SmishingInitial)
                  TextButton(
                    onPressed: _reset,
                    child: const Text('Analizar otro SMS'),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
