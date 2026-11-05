import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/diagnostics/diagnostic_event.dart';
import 'diagnostics_providers.dart';

/// Capture the account journal at operation start without rebuilding the coordinator.
final trustedCallerDiagnosticsProvider = Provider<DiagnosticSink Function()>((
  ref,
) {
  return () {
    try {
      return ref.read(diagnosticJournalProvider).record;
    } catch (_) {
      return (_) {};
    }
  };
});
