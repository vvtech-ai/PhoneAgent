import 'voice_gateway_event.dart';

abstract interface class VoiceInputSession {
  Stream<VoiceGatewayEvent> get events;
  Future<void> start(Uri endpoint);

  /// Hardware stop; deliberately separate from the user's release gesture.
  Future<void> release();
  Future<void> cancel();
}
