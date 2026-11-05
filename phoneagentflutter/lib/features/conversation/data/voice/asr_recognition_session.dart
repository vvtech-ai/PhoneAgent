import 'dart:typed_data';
import '../../domain/voice/voice_gateway_event.dart';

/// Wire-only recognition. Capture and gesture submission are separate owners.
abstract interface class AsrRecognitionSession {
  Stream<VoiceGatewayEvent> get events;
  Future<void> start(Uri endpoint);
  bool sendPcm(Uint8List pcm);
  void release();
  Future<void> cancel();
}
