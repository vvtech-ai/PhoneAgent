import 'dart:async';
import 'dart:typed_data';
import '../../../core/diagnostics/diagnostic_event.dart';
import '../../../core/diagnostics/media_diagnostics.dart';
import '../../conversation/data/voice/voice_socket.dart';
import '../domain/call_monitor_media.dart';
import '../domain/call_session.dart';

class CallMonitorStream implements CallMonitorMedia, CallMonitorAudioReadiness {
  CallMonitorStream({
    required this.apiBase,
    required this.connect,
    required this.output,
    this.diagnostics,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;
  final Uri apiBase;
  final VoiceSocketConnector connect;
  final CallMonitorOutput output;
  final MediaDiagnostics? diagnostics;
  final DateTime Function() now;
  final _disconnected = StreamController<void>(
    sync: true,
    onCancel: () => Future<void>.microtask(() {}),
  );
  VoiceSocket? _socket;
  StreamSubscription<Object>? _subscription;
  Future<void>? _closing;
  bool _closed = false, _used = false, _enabled = true, _reported = false;
  bool _receivingPaused = false;
  bool _received = false;
  int _generation = 0, _pending = 0, _rate = 0;
  final _firstPcm = Completer<bool>();
  @override
  Future<bool> get audioStarted => _firstPcm.future;
  @override
  Stream<void> get disconnected => _disconnected.stream;
  void _check() {
    if (_closed) throw const CallMonitorFailure('cancelled');
  }

  static Uri endpoint(Uri base, CallMonitorTicket ticket, DateTime now) {
    if (!{'http', 'https'}.contains(base.scheme) ||
        base.host.isEmpty ||
        base.userInfo.isNotEmpty ||
        base.hasQuery ||
        base.hasFragment ||
        ticket.ticket.isEmpty ||
        !ticket.expiresAt.isAfter(now) ||
        ticket.channels != 1 ||
        ticket.sampleRate < 8000 ||
        ticket.sampleRate > 48000 ||
        ticket.encoding.toUpperCase() != 'PCM_S16LE') {
      throw const CallMonitorFailure('invalid_ticket');
    }
    final path =
        '${base.path.replaceFirst(RegExp(r'/+$'), '')}/ws/assistant/call/monitor';
    return base.replace(
      scheme: base.scheme == 'https' ? 'wss' : 'ws',
      path: path,
      queryParameters: {'ticket': ticket.ticket},
    );
  }

  @override
  Future<void> start(CallMonitorTicket ticket, String initialRoute) async {
    _check();
    if (_used) throw const CallMonitorFailure('used');
    _used = true;
    final uri = endpoint(apiBase, ticket, now());
    _rate = ticket.sampleRate;
    var stage = DiagnosticMediaStage.start;
    late VoiceSocket socket;
    try {
      diagnostics?.record(stage, DiagnosticResult.started);
      await output.start(_rate);
      _check();
      await output.route(select: initialRoute);
      _check();
      diagnostics?.record(stage, DiagnosticResult.succeeded);
      stage = DiagnosticMediaStage.connect;
      diagnostics?.record(stage, DiagnosticResult.started);
      socket = await connect(uri);
      diagnostics?.record(stage, DiagnosticResult.succeeded);
    } catch (_) {
      diagnostics?.record(
        stage,
        DiagnosticResult.failed,
        reason: stage == DiagnosticMediaStage.connect
            ? DiagnosticMediaReason.connectFailed
            : DiagnosticMediaReason.deviceFailure,
      );
      rethrow;
    }
    if (_closed) {
      await socket.close();
      throw const CallMonitorFailure('cancelled');
    }
    _socket = socket;
    _subscription = socket.messages.listen(
      _message,
      onError: (Object _) =>
          _lost(reason: DiagnosticMediaReason.transportError),
      onDone: () => _lost(reason: DiagnosticMediaReason.providerClosed),
    );
  }

  void _lost({bool retryable = true, required DiagnosticMediaReason reason}) {
    if (_closed || _reported) return;
    _reported = true;
    diagnostics?.record(
      DiagnosticMediaStage.protocol,
      DiagnosticResult.failed,
      reason: reason,
    );
    if (!_firstPcm.isCompleted) _firstPcm.complete(false);
    if (retryable) {
      _disconnected.add(null);
    } else {
      _disconnected.addError(const CallMonitorFailure('output_failed'));
    }
  }

  void _message(Object message) {
    if (_closed || _reported || !_enabled || message is! List<int>) return;
    if (message.isEmpty) return;
    if (message.length.isOdd || _pending + message.length > _rate * 4) {
      _lost(
        reason: message.length.isOdd
            ? DiagnosticMediaReason.invalidPcm
            : DiagnosticMediaReason.audioLimit,
      );
      return;
    }
    if (!_received) {
      _received = true;
      diagnostics?.record(
        DiagnosticMediaStage.receive,
        DiagnosticResult.received,
      );
    }
    final generation = _generation;
    final bytes = Uint8List.fromList(message);
    _pending += bytes.length;
    // Native playback completes at the hardware head. Bound admitted audio
    // while pausing the socket instead of reconnecting on a valid AI burst.
    if (_pending >= _rate * 2 && !_receivingPaused) {
      _receivingPaused = true;
      _subscription?.pause();
      diagnostics?.record(DiagnosticMediaStage.read, DiagnosticResult.started);
    }
    unawaited(
      Future.sync(() => output.play(bytes)).then(
        (_) {
          if (generation == _generation) {
            _pending -= bytes.length;
            if (_pending <= _rate) _resumeReceiving();
            if (!_closed && !_reported && !_firstPcm.isCompleted) {
              _firstPcm.complete(true);
              diagnostics?.record(
                DiagnosticMediaStage.play,
                DiagnosticResult.succeeded,
              );
            }
          }
        },
        onError: (Object _, StackTrace __) {
          if (generation == _generation) {
            _pending -= bytes.length;
            _lost(
              retryable: false,
              reason: DiagnosticMediaReason.deviceFailure,
            );
          }
        },
      ),
    );
  }

  void _resumeReceiving() {
    if (!_receivingPaused) return;
    _receivingPaused = false;
    _subscription?.resume();
    diagnostics?.record(DiagnosticMediaStage.read, DiagnosticResult.succeeded);
  }

  @override
  Future<void> setPlaybackEnabled(bool enabled) async {
    _check();
    // Invalidate pending playback before flushing its native callbacks.
    _enabled = false;
    _generation++;
    _pending = 0;
    final wasPaused = _receivingPaused;
    _resumeReceiving();
    await output.setPlaybackEnabled(enabled);
    // Buffered socket events must be discarded while disabled before unmuting.
    if (wasPaused) await Future<void>.delayed(Duration.zero);
    _check();
    _enabled = enabled;
  }

  @override
  Future<CallMonitorRoute> route({String? select}) {
    _check();
    return output.route(select: select);
  }

  @override
  Future<void> close() {
    _closed = true;
    _enabled = false;
    _generation++;
    if (!_firstPcm.isCompleted) _firstPcm.complete(false);
    return _closing ??= _release();
  }

  Future<void> _release() async {
    var failed = false;
    try {
      await _subscription?.cancel();
    } catch (_) {
      failed = true;
    }
    _subscription = null;
    try {
      await _socket?.close();
    } catch (_) {
      failed = true;
    }
    try {
      await output.stop();
    } catch (_) {
      failed = true;
    }
    if (failed) {
      diagnostics?.record(
        DiagnosticMediaStage.close,
        DiagnosticResult.failed,
        reason: DiagnosticMediaReason.deviceFailure,
      );
      _closing = null;
      throw const CallMonitorFailure('release_failed');
    }
    diagnostics?.record(DiagnosticMediaStage.close, DiagnosticResult.succeeded);
    if (!_disconnected.isClosed) unawaited(_disconnected.close());
  }
}
