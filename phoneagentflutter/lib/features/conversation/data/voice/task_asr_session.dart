import 'dart:async';
import 'dart:typed_data';
import '../../../../core/diagnostics/diagnostic_event.dart';
import '../../../../core/diagnostics/media_diagnostics.dart';
import '../../domain/voice/capture_turn_gate.dart';
import '../../domain/voice/voice_gateway_event.dart';
import 'task_voice_codec.dart';
import 'voice_socket.dart';
import 'voice_socket_factory.dart';
import 'voice_wire.dart';
import 'asr_recognition_session.dart';

/// One ASR connection and one capture token. Owns no microphone or UI.
class TaskAsrSession implements AsrRecognitionSession {
  TaskAsrSession({
    VoiceSocketConnector connector = connectVoiceSocket,
    this.readyTimeout = const Duration(seconds: 10),
    this.idleTimeout = const Duration(seconds: 90),
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
  final Duration readyTimeout, idleTimeout;
  final MediaDiagnostics? diagnostics;
  final _events = StreamController<VoiceGatewayEvent>.broadcast(sync: true);
  final _gate = CaptureTurnGate();
  late final VoiceWire _wire;
  CaptureTurn? _turn;
  Timer? _readyTimer, _idleTimer;
  bool _closed = false;
  @override
  Stream<VoiceGatewayEvent> get events => _events.stream;
  CapturePhase get phase => _gate.phase;

  @override
  Future<void> start(Uri endpoint) async {
    if (_closed || _turn != null) throw StateError('ASR session already used');
    _turn = _gate.begin();
    _readyTimer = Timer(readyTimeout, () => _fail('ready_timeout'));
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
      if (!_gate.ready(_turn!)) return;
      diagnostics?.record(
        DiagnosticMediaStage.ready,
        DiagnosticResult.received,
      );
      _readyTimer?.cancel();
      if (_wire.send(TaskVoiceCodec.startCapture()) && !_closed) {
        _events.add(event);
      }
    } else if (event is VoiceTranscript) {
      if (_gate.accept(_turn!, event)) _events.add(event);
    } else if (event is VoiceGatewayFailure) {
      _fail('provider_error');
    } else if (event != null && phase == CapturePhase.capturing) {
      _events.add(event);
    }
  }

  @override
  bool sendPcm(Uint8List pcm) {
    if (_closed || _turn == null || !_gate.allowsPcm(_turn!)) return false;
    // AudioRecord may return a short frame; PCM16 must contain whole samples.
    if (pcm.isEmpty ||
        pcm.length.isOdd ||
        pcm.length > TaskVoiceCodec.asrFrameBytes) {
      _fail('invalid_pcm');
      return false;
    }
    return _wire.send(Uint8List.fromList(pcm));
  }

  @override
  void release() {
    if (_closed || _turn == null) return;
    final wasWaiting = phase == CapturePhase.awaitingReady;
    if (_gate.release(_turn!)) {
      _wire.send(TaskVoiceCodec.stopCapture(reason: 'user_release'));
      if (!_closed) {
        _idleTimer = Timer(idleTimeout, () => _close('idle_timeout'));
      }
    } else if (wasWaiting) {
      unawaited(_close('released_before_ready'));
    }
  }

  void _fail(String reason) {
    if (_closed) return;
    diagnostics?.failure(reason);
    _events.add(VoiceGatewayFailure(reason));
    unawaited(_close(reason));
  }

  @override
  Future<void> cancel() => _close('cancelled');
  Future<void> _close(String reason) async {
    if (_closed) return;
    _closed = true;
    _readyTimer?.cancel();
    _idleTimer?.cancel();
    if (_turn != null) _gate.cancel(_turn!);
    await _wire.close(TaskVoiceCodec.finish(reason: reason));
    _events.add(VoiceTransportClosed(reason));
    await _events.close();
  }
}
