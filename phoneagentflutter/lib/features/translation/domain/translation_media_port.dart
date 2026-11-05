import 'translation_backend_session.dart';
import 'translation_realtime_event.dart';

enum TranslationMediaTransport { liveKit, websocket }

abstract interface class TranslationMediaPort {
  /// Completes only after room+realtime readiness (LiveKit), or app_audio_ready
  /// (WebSocket). Socket open / a received connection ticket is insufficient.
  Future<void> connect(TranslationBackendSession session);

  /// Must cancel outstanding connect work and prevent late device/audio activity.
  Future<void> close();
}

/// Event-capable media adapter. Connect owns readiness; this stream delivers
/// ongoing protocol messages, and errors/done mean the active link was lost.
abstract interface class TranslationInteractiveMediaPort
    implements TranslationMediaPort {
  Stream<TranslationRealtimeMessage> get events;
  bool get supportsDtmf;
  Future<void> setMuted(bool muted);
  Future<void> setSpeaker(bool enabled);
  Future<void> sendDtmf(String digit);
}

typedef TranslationMediaFactory =
    TranslationMediaPort Function(TranslationMediaTransport transport);
