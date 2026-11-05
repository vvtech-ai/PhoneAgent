import 'dart:async';
import 'dart:typed_data';
import '../../../../core/diagnostics/diagnostic_event.dart';
import '../../../../core/diagnostics/media_diagnostics.dart';
import '../../domain/voice/voice_gateway_event.dart';
import 'asr_recognition_session.dart';
import 'task_voice_codec.dart';
import 'voice_socket.dart';
import 'voice_socket_factory.dart';
import 'voice_wire.dart';

/// v65 backend transcription: ready + binary PCM, no task-ASR JSON controls.
class RealtimeTranscriptionSession implements AsrRecognitionSession {
  RealtimeTranscriptionSession({
    VoiceSocketConnector connector = connectVoiceSocket,
    this.readyTimeout = const Duration(seconds: 8),
    this.diagnostics,
  }) {
    _wire = VoiceWire(
      connector,
      onMessage: _message,
      onFailure: _fail,
      onClosed: () => _fail('provider_closed'),
      diagnostics: diagnostics,
    );
  }
  final Duration readyTimeout;
  final MediaDiagnostics? diagnostics;
  late final VoiceWire _wire;
  final _events = StreamController<VoiceGatewayEvent>.broadcast(sync: true);
  Timer? _timer;
  bool _used = false, _ready = false, _closed = false;
  Future<void>? _closing;
  @override
  Stream<VoiceGatewayEvent> get events => _events.stream;

  @override
  Future<void> start(Uri endpoint) async {
    if (_used || _closed) {
      throw StateError('Transcription session already used');
    }
    _used = true;
    _timer = Timer(readyTimeout, () => _fail('ready_timeout'));
    await _wire.open(endpoint);
  }

  void _message(Object message) {
    if (_closed) return;
    if (message is! String) {
      _fail('invalid_frame');
      return;
    }
    final event = TaskVoiceCodec.decodeAsr(message);
    if (event is VoiceReady) {
      if (_ready) return;
      _ready = true;
      diagnostics?.record(
        DiagnosticMediaStage.ready,
        DiagnosticResult.received,
      );
      _timer?.cancel();
      _events.add(event);
    } else if (event is VoiceGatewayFailure) {
      _fail('provider_error');
    } else if (_ready && (event is VoiceTranscript || event is VoiceStatus)) {
      _events.add(event!);
    }
  }

  @override
  bool sendPcm(Uint8List pcm) {
    if (_closed || !_ready) return false;
    if (pcm.isEmpty ||
        pcm.length.isOdd ||
        pcm.length > TaskVoiceCodec.asrFrameBytes) {
      _fail('invalid_pcm');
      return false;
    }
    return _wire.send(Uint8List.fromList(pcm));
  }

  void _fail(String reason) {
    if (_closed) return;
    diagnostics?.failure(reason);
    _events.add(VoiceGatewayFailure(reason));
    unawaited(_close(reason));
  }

  /// Unlike task ASR, this transport has no late-final-after-stop contract.
  /// The gesture's two-second tail happens before this explicit stop.
  @override
  void release() => unawaited(_close('released'));
  @override
  Future<void> cancel() => _close('cancelled');
  Future<void> _close(String reason) => _closing ??= _shutdown(reason);
  Future<void> _shutdown(String reason) async {
    _closed = true;
    _ready = false;
    _timer?.cancel();
    await _wire.close();
    _events.add(VoiceTransportClosed(reason));
    await _events.close();
  }
}
