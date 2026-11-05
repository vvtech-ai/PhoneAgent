import 'dart:async';
import 'dart:typed_data';
import '../../../../core/diagnostics/diagnostic_event.dart';
import '../../../../core/diagnostics/media_diagnostics.dart';
import '../../../../core/network/signing/c1_transport.dart';
import '../../domain/voice/voice_gateway_event.dart';
import 'task_voice_codec.dart';
import 'voice_socket.dart';
import 'voice_socket_factory.dart';
import 'voice_wire.dart';

part 'task_tts_session_connection.dart';

/// A session-scoped synthesis channel. The client WSS stays ready between
/// serialized requests; one request can replace the provider connection once
/// when no first PCM arrives.
class TaskTtsSession {
  TaskTtsSession({
    VoiceSocketConnector connector = connectVoiceSocket,
    Duration firstAudioTimeout = const Duration(seconds: 5),
    this.maxAudioBytes = 16 * 1024 * 1024,
    this.diagnostics,
    this.reuseEnabled = true,
    Duration heartbeatInterval = const Duration(seconds: 15),
    int maxRecoveryRetries = 1,
  }) : _connector = connector,
       firstAudioTimeout = _safeFirstAudioTimeout(firstAudioTimeout),
       heartbeatInterval = _safeHeartbeatInterval(heartbeatInterval),
       _maxRecoveryRetries = maxRecoveryRetries.clamp(0, 1) {
    _wire = _newWire();
  }

  final VoiceSocketConnector _connector;
  final Duration firstAudioTimeout;
  final int maxAudioBytes;
  final MediaDiagnostics? diagnostics;
  final bool reuseEnabled;
  final Duration heartbeatInterval;
  final int _maxRecoveryRetries;
  final _events = StreamController<VoiceGatewayEvent>.broadcast(sync: true);
  final _buffer = BytesBuilder(copy: false);

  int _wireGeneration = 0;
  int _requestGeneration = 0;
  String _mediaRequestId = '';
  MediaDiagnostics? _attemptDiagnostics;
  MediaDiagnostics? _requestDiagnostics;
  Uri? _endpoint;
  String _text = '';
  VoiceWire? _wire;
  Timer? _firstTimer, _completeTimer, _heartbeatTimer;
  String? _request;
  bool _ready = false;
  bool _active = false;
  bool _closed = false;
  bool _sent = false;
  bool _streaming = false;
  bool _recovering = false;
  bool _heartbeatPending = false;
  bool _networkAvailable = true;
  int _received = 0;
  int _recoveryRetries = 0;
  int _attempt = 0;
  Stopwatch? _requestClock;

  Stream<VoiceGatewayEvent> get events => _events.stream;
  bool get active => _active;
  bool get closed => _closed;

  /// Availability is a pause signal, not proof that an utterance failed.
  /// Recovery shares the existing one-replacement budget.
  void setNetworkAvailable(bool available) {
    if (_closed || _networkAvailable == available) return;
    _networkAvailable = available;
    if (available) {
      if (_active) unawaited(_recover('network_changed'));
      return;
    }
    if (_active && _streaming) {
      _fail('network_changed'); // Delivered PCM cannot be replayed safely.
      return;
    }
    _recordAttempt(
      DiagnosticMediaStage.close,
      DiagnosticResult.cancelled,
      reason: DiagnosticMediaReason.networkChanged,
    );
    _cancelTimers();
    _ready = false;
    _recovering = false;
    _wireGeneration++;
    final old = _wire;
    _wire = null;
    unawaited(old?.close(TaskVoiceCodec.cancelSynthesis()));
  }

  /// Drops the current transport without ending the session object. The next
  /// request will create a fresh wire and perform the normal ready handshake.
  /// An in-flight request is failed once so callers do not wait on a socket
  /// that was invalidated by a network or lifecycle transition.
  Future<void> invalidateTransport([
    String reason = 'transport_invalidated',
  ]) async {
    if (_closed) return;
    if (_active) {
      _fail(reason);
      return;
    }
    _cancelTimers();
    _ready = false;
    _wireGeneration++;
    final old = _wire;
    _wire = _newWire();
    await old?.close();
  }

  static Duration completionTimeout(String text) =>
      Duration(milliseconds: (text.trim().length * 350).clamp(15000, 60000));

  static Duration _safeFirstAudioTimeout(Duration value) =>
      value < const Duration(milliseconds: 100)
      ? const Duration(milliseconds: 100)
      : value > const Duration(seconds: 30)
      ? const Duration(seconds: 30)
      : value;

  static Duration _safeHeartbeatInterval(Duration value) =>
      value < const Duration(seconds: 1)
      ? const Duration(seconds: 1)
      : value > const Duration(seconds: 120)
      ? const Duration(seconds: 120)
      : value;

  VoiceWire _newWire() {
    final wireGeneration = ++_wireGeneration;
    try {
      _mediaRequestId = C1Transport.newDeviceId();
    } catch (_) {
      _mediaRequestId = ''; // Diagnostic randomness cannot prevent playback.
    }
    _attemptDiagnostics = (_requestDiagnostics ?? diagnostics)?.withRequest(
      _mediaRequestId,
      wireGeneration,
    );
    final wire = VoiceWire(
      _connector,
      onMessage: (message) {
        if (wireGeneration == _wireGeneration) {
          _message(message, wireGeneration);
        }
      },
      onFailure: (reason) {
        if (wireGeneration == _wireGeneration) _transportFailure(reason);
      },
      onClosed: () {
        if (wireGeneration == _wireGeneration) {
          _transportFailure('provider_closed');
        }
      },
      diagnostics: _attemptDiagnostics,
    );
    _wire = wire;
    return wire;
  }

  /// Opens only the connection; never sends synthesis text.
  Future<void> prewarm(Uri endpoint) => _prewarmConnection(endpoint);

  Future<void> start(
    Uri endpoint, {
    required String text,
    required String speaker,
    MediaDiagnostics? requestDiagnostics,
  }) async {
    if (_closed || _active) throw StateError('TTS session is busy or closed');
    _requestDiagnostics = requestDiagnostics;
    _attemptDiagnostics = (requestDiagnostics ?? diagnostics)?.withRequest(
      _mediaRequestId,
      _wireGeneration,
    );
    _endpoint = endpoint;
    _text = text;
    final requestGeneration = ++_requestGeneration;
    _request = TaskVoiceCodec.synthesize(
      text: text,
      speaker: speaker,
      generation: requestGeneration,
    );
    _active = true;
    _ready = _ready && (_wire?.connected ?? false);
    _sent = false;
    _streaming = false;
    _received = 0;
    _recoveryRetries = 0;
    _attempt = 1;
    _requestClock = Stopwatch()..start();
    _buffer.clear();
    if (!_networkAvailable) return;
    _armCompletionTimer();

    final wire = _wire ?? _newWire();
    if (_ready) {
      _sendRequestIfReady();
      return;
    }
    if (!wire.connected) await wire.open(_diagnosticEndpoint(endpoint));
    if (_active && requestGeneration == _requestGeneration && _wire == wire) {
      if (_ready) _sendRequestIfReady();
    }
  }

  Uri _diagnosticEndpoint(Uri endpoint) => _mediaRequestId.isEmpty
      ? endpoint
      : endpoint.replace(
          queryParameters: {
            ...endpoint.queryParametersAll,
            'mediaRequestId': _mediaRequestId,
          },
        );

  void _armCompletionTimer() {
    _firstTimer?.cancel();
    _completeTimer?.cancel();
    _firstTimer = null;
    _completeTimer = Timer(completionTimeout(_text), () {
      if (!_active) return;
      if (_received > 0) {
        _complete(softTimeout: true);
      } else {
        _recover('completion_timeout');
      }
    });
  }

  void _sendRequestIfReady() {
    if (!_active || _sent || !_ready) return;
    final request = _request;
    final wire = _wire;
    if (request == null || wire == null) return;
    _sent = true;
    if (!wire.send(request)) {
      _sent = false;
      _transportFailure('send_failed');
      return;
    }
    _recordAttempt(DiagnosticMediaStage.send, DiagnosticResult.succeeded);
    // A connection/ready delay is excluded from the first-audio budget.
    _firstTimer?.cancel();
    _firstTimer = Timer(
      firstAudioTimeout,
      () => _recover('first_audio_timeout'),
    );
  }

  void _message(Object message, int wireGeneration) {
    if (_closed || wireGeneration != _wireGeneration) return;
    if (message is Uint8List) {
      if (!_active) return;
      if (!_sent || message.length.isOdd) {
        _fail('invalid_pcm');
        return;
      }
      if (message.isEmpty) return;
      if (_received + message.length > maxAudioBytes) {
        _fail('audio_limit');
        return;
      }
      if (_received == 0) {
        _recordAttempt(
          DiagnosticMediaStage.receive,
          DiagnosticResult.received,
          audioBytes: message.length,
        );
        if (_attempt > 1) {
          _recordAttempt(
            DiagnosticMediaStage.retry,
            DiagnosticResult.succeeded,
          );
        }
      }
      _received += message.length;
      _firstTimer?.cancel();
      _buffer.add(message);
      if (_buffer.length >= (_streaming ? 5760 : 24000)) {
        _streaming = true;
        _flush();
      }
      return;
    }
    if (message is! String) {
      _fail('invalid_frame');
      return;
    }
    final event = TaskVoiceCodec.decodeTts(message);
    if (event is VoiceReady) {
      if (_ready) return;
      _ready = true;
      _armHeartbeat();
      _attemptDiagnostics?.record(
        DiagnosticMediaStage.ready,
        DiagnosticResult.received,
        elapsedMs: _requestClock?.elapsedMilliseconds ?? 0,
      );
      if (_attempt > 1) {
        _recordAttempt(
          DiagnosticMediaStage.reconnect,
          DiagnosticResult.succeeded,
        );
        _recordAttempt(DiagnosticMediaStage.retry, DiagnosticResult.started);
      }
      _sendRequestIfReady();
      if (!_closed) _events.add(event);
    } else if (event is VoiceHeartbeatPong) {
      _heartbeatPending = false;
    } else if (!_active) {
      return;
    } else if (event is VoiceReconnectRequired) {
      unawaited(_recover('reconnect_required'));
    } else if (event is VoiceSynthesisStarted) {
      if (_matchesRequest(event.generation)) _events.add(event);
    } else if (event is VoiceSynthesisComplete) {
      if (!_matchesRequest(event.generation)) return;
      if (!_sent) {
        _fail('unexpected_complete');
      } else if (_received == 0) {
        _recover('empty_audio');
      } else {
        _complete(generation: event.generation);
      }
    } else if (event is VoiceGatewayFailure) {
      _fail('provider_error');
    }
  }

  bool _matchesRequest(int? generation) =>
      generation == null || generation == _requestGeneration;

  void _transportFailure(String reason) {
    if (_closed) return;
    if (!_active) {
      unawaited(invalidateTransport(reason));
      return;
    }
    _recover(reason);
  }

  void _flush() {
    if (_buffer.isNotEmpty) _events.add(VoicePcmChunk(_buffer.takeBytes()));
  }

  void _complete({bool softTimeout = false, int? generation}) {
    if (_closed || !_active) return;
    _recordAttempt(
      DiagnosticMediaStage.complete,
      DiagnosticResult.received,
      reason: softTimeout ? DiagnosticMediaReason.softTimeout : null,
    );
    final completedGeneration = _requestGeneration;
    _active = false;
    _recovering = false;
    _sent = false;
    _request = null;
    _text = '';
    _requestClock?.stop();
    _cancelRequestTimers();
    _flush();
    _events.add(
      VoiceSynthesisComplete(
        softTimeout: softTimeout,
        generation: generation ?? completedGeneration,
      ),
    );
    if (!reuseEnabled || softTimeout) {
      _cancelTimers();
      _ready = false;
      _wireGeneration++;
      final old = _wire;
      _wire = _newWire();
      unawaited(old?.close());
    }
  }

  Future<void> _recover(String reason) async {
    if (_closed || !_active || _recovering) return;
    if (_streaming) {
      _fail(reason);
      return;
    }
    if (!_networkAvailable) return;
    if (_recoveryRetries >= _maxRecoveryRetries) {
      _fail(reason);
      return;
    }
    _recovering = true;
    _recoveryRetries++;
    _attempt = _recoveryRetries + 1;
    _recordAttempt(DiagnosticMediaStage.reconnect, DiagnosticResult.started);
    final endpoint = _endpoint;
    final requestGeneration = _requestGeneration;
    final old = _wire;
    _cancelTimers();
    _buffer.clear();
    _received = 0;
    _streaming = false;
    _sent = false;
    _ready = false;
    _wireGeneration++;
    final replacement = _newWire();
    try {
      // A stale socket's shutdown must not block the replacement handshake.
      unawaited(old?.close(TaskVoiceCodec.cancelSynthesis()));
      if (_closed || !_active || endpoint == null) return;
      _armCompletionTimer();
      await replacement.open(_diagnosticEndpoint(endpoint));
      if (_closed ||
          !_active ||
          _wire != replacement ||
          requestGeneration != _requestGeneration) {
        return;
      }
      if (_active && !_ready && !replacement.connected) {
        _fail('connect_failed');
      }
    } finally {
      if (_wire == replacement) _recovering = false;
    }
  }

  void _fail(String reason) {
    if (_closed || !_active) return;
    _attemptDiagnostics?.failure(
      reason,
      connectionEpoch: _wireGeneration,
      audioBytes: _received,
      ready: _ready,
      requestSent: _sent,
      requestGeneration: _requestGeneration,
      attempt: _attempt,
      elapsedMs: _requestClock?.elapsedMilliseconds ?? 0,
    );
    _active = false;
    _recovering = false;
    _cancelTimers();
    _buffer.clear();
    _request = null;
    _requestGeneration++;
    _requestClock?.stop();
    _sent = false;
    _ready = false;
    _events.add(VoiceGatewayFailure(reason));
    _wireGeneration++;
    final old = _wire;
    _wire = _newWire();
    unawaited(old?.close(TaskVoiceCodec.cancelSynthesis()));
  }

  void _recordAttempt(
    DiagnosticMediaStage stage,
    DiagnosticResult result, {
    DiagnosticMediaReason? reason,
    int? audioBytes,
  }) => _attemptDiagnostics?.record(
    stage,
    result,
    reason: reason,
    connectionEpoch: _wireGeneration,
    audioBytes: audioBytes ?? _received,
    ready: _ready,
    requestSent: _sent,
    requestGeneration: _requestGeneration,
    attempt: _attempt,
    elapsedMs: _requestClock?.elapsedMilliseconds ?? 0,
  );

  Future<void> cancel() async {
    if (_closed) return;
    if (_active) {
      _recordAttempt(DiagnosticMediaStage.complete, DiagnosticResult.cancelled);
    }
    _closed = true;
    _active = false;
    _cancelTimers();
    _buffer.clear();
    _request = null;
    _requestGeneration++;
    _requestClock?.stop();
    _recordAttempt(DiagnosticMediaStage.close, DiagnosticResult.cancelled);
    _wireGeneration++;
    final wire = _wire;
    _wire = null;
    await wire?.close(TaskVoiceCodec.cancelSynthesis());
    await _events.close();
  }
}
