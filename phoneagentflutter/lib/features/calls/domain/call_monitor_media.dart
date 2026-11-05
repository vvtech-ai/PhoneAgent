import '../../../core/audio/pcm_output.dart';
import 'call_session.dart';

class CallMonitorRoute {
  const CallMonitorRoute({this.selected = 'earpiece', this.bluetooth = false});
  final String selected;
  final bool bluetooth;
}

abstract interface class CallMonitorOutput implements PcmOutput {
  Future<void> setPlaybackEnabled(bool enabled);
  Future<CallMonitorRoute> route({String? select});
}

/// One ticket/connection. Receive-only; no microphone or call-control commands.
abstract interface class CallMonitorMedia {
  Stream<void> get disconnected;
  Future<void> start(CallMonitorTicket ticket, String initialRoute);
  Future<void> setPlaybackEnabled(bool enabled);
  Future<CallMonitorRoute> route({String? select});
  Future<void> close();
}

/// Optional playback readiness for streaming outputs; handshake is insufficient.
abstract interface class CallMonitorAudioReadiness {
  Future<bool> get audioStarted;
}

class CallMonitorFailure implements Exception {
  const CallMonitorFailure(this.code);
  final String code;
  @override
  String toString() => 'CallMonitorFailure($code)';
}
