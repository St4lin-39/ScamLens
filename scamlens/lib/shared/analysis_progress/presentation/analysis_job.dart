import '../domain/analysis_progress.dart';

/// One pending computation, with replay when a newer request reattaches to it.
/// No Flutter/BLoC dependency; the owner decides whether a listener is current.
class AnalysisJob<T> {
  late final Future<T> future;
  AnalysisProgressSnapshot snapshot = const AnalysisProgressSnapshot.empty();
  void Function(AnalysisProgressSnapshot)? _listener;
  bool _disposed = false;

  AnalysisJob(Future<T> Function(AnalysisProgressCallback) action) {
    future = Future<T>.sync(() => action(report));
  }

  void report(AnalysisProgress event) {
    if (_disposed) return;
    snapshot = snapshot.add(event);
    _listener?.call(snapshot);
  }

  void observe(void Function(AnalysisProgressSnapshot) listener) {
    if (_disposed) return;
    _listener = listener;
    if (snapshot.stages.isNotEmpty) listener(snapshot);
  }

  void detach(void Function(AnalysisProgressSnapshot) listener) {
    if (identical(_listener, listener)) _listener = null;
  }

  void dispose() {
    _disposed = true;
    _listener = null;
  }
}
