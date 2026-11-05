import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/conversation/domain/conversation_ids.dart';
import '../core/diagnostics/diagnostic_event.dart';
import '../core/diagnostics/media_diagnostics.dart';
import 'diagnostics_providers.dart';

/// Capture once per input/reply/preview, before asynchronous work or fallback.
class MediaDiagnosticScope {
  MediaDiagnosticScope(this.sink) : traceId = _trace();
  static String _trace() {
    try {
      final id = newConversationId();
      return '${id.substring(0, 8)}-${id.substring(8, 12)}-'
          '${id.substring(12, 16)}-${id.substring(16, 20)}-${id.substring(20)}';
    } catch (_) {
      return ''; // Even unavailable randomness must not block audio creation.
    }
  }

  final DiagnosticSink? sink;
  final String traceId;
  MediaDiagnostics forComponent(DiagnosticMediaComponent component) =>
      MediaDiagnostics(sink, component, traceId: traceId);
}

final mediaDiagnosticScopeFactoryProvider =
    Provider<MediaDiagnosticScope Function()>((ref) {
      // Reading rather than watching does not rebuild an active audio factory.
      return () {
        DiagnosticSink? sink;
        try {
          sink = ref.read(diagnosticJournalProvider).record;
        } catch (_) {
          // The diagnostics store cannot prevent microphone/playback creation.
        }
        return MediaDiagnosticScope(sink);
      };
    });
