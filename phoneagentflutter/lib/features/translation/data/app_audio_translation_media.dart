import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';
import '../../../core/diagnostics/diagnostic_event.dart';
import '../../../core/diagnostics/media_diagnostics.dart';
import '../../../core/audio/audio_playback_focus.dart';
import '../../../core/audio/audio_resource_coordinator.dart';
import '../../conversation/data/voice/voice_socket.dart';
import '../../conversation/domain/tools/conversation_permission.dart';
import '../domain/translation_backend_session.dart';
import '../domain/translation_media_port.dart';
import '../domain/translation_pcm_bridge.dart';
import '../domain/translation_realtime_event.dart';
import 'translation_realtime_codec.dart';

/// AppAudio readiness and duplex orchestration shared by both mobile platforms.
class AppAudioTranslationMedia implements TranslationInteractiveMediaPort {
  AppAudioTranslationMedia({
    required this.connector,
    required this.audio,
    required this.permissions,
    required this.focus,
    required this.isCurrent,
    this.readyTimeout = const Duration(seconds: 10),
    this.diagnostics,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;
  final VoiceSocketConnector connector;
  final TranslationPcmBridge audio;
  final ConversationPermissionSource permissions;
  final AudioPlaybackFocus focus;
  final bool Function() isCurrent;
  final Duration readyTimeout;
  final MediaDiagnostics? diagnostics;
  MediaDiagnostics? _diagnostics;
  DiagnosticMediaStage _stage = DiagnosticMediaStage.connect;
  DiagnosticMediaStage _captureStage = DiagnosticMediaStage.start;
  bool _readNoted = false, _sentNoted = false, _playedNoted = false;
  final DateTime Function() now;
  final _events = StreamController<TranslationRealtimeMessage>(
    sync: true,
    onCancel: () => Future<void>.microtask(() {}),
  );
  final _ready = Completer<bool>();
  final _queue = Queue<TranslationAudio>();
  VoiceSocket? _socket;
  StreamSubscription<Object>? _subscription;
  AudioLease? _lease;
  Future<void>? _captureStart, _cleanup;
  Timer? _accountCheck;
  String _sessionId = '';
  bool _closed = false, _broken = false, _used = false, _connected = false;
  bool _muted = false, _speaker = false, _pumping = false;
  int _lastSequence = -1;
  double _pendingSeconds = 0;
  bool get _current => !_closed && !_broken && isCurrent();
  @override
  bool get supportsDtmf => false;
  @override
  Stream<TranslationRealtimeMessage> get events => _events.stream;
  void _check() {
    if (!_current) throw StateError('Translation AppAudio unavailable');
  }

  static Uri endpoint(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        uri.scheme != 'wss' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment) {
      throw StateError('Invalid translation audio endpoint');
    }
    if (uri.queryParameters.containsKey('downlinkAudio')) return uri;
    return uri.replace(
      query:
          '${uri.hasQuery && uri.query.isNotEmpty ? '${uri.query}&' : ''}downlinkAudio=binary',
    );
  }

  @override
  Future<void> connect(TranslationBackendSession session) async {
    _check();
    if (_used || session.id.isEmpty) {
      throw StateError('Invalid media lifecycle');
    }
    _used = true;
    _sessionId = session.id;
    _diagnostics = diagnostics?.withSession(session.id);
    _diagnostics?.record(
      DiagnosticMediaStage.connect,
      DiagnosticResult.started,
    );
    final Uri uri;
    try {
      uri = endpoint(session.appAudioWsUrl);
    } catch (_) {
      _diagnostics?.record(
        DiagnosticMediaStage.protocol,
        DiagnosticResult.failed,
        reason: DiagnosticMediaReason.invalidFrame,
      );
      rethrow;
    }
    try {
      _stage = DiagnosticMediaStage.permission;
      final grant = await permissions.resolve(
        ConversationPermission.microphone,
        request: false,
      );
      _check();
      if (grant != PermissionGrant.granted) {
        throw StateError('Microphone permission required');
      }
      _stage = DiagnosticMediaStage.start;
      _lease = await focus.acquire(
        owner: 'translation-app-audio',
        isCurrent: () => _current,
        interruptible: false,
        stop: (_) => close(),
      );
      _check();
      _stage = DiagnosticMediaStage.connect;
      final socket = await connector(uri);
      if (!_current) {
        await socket.close();
        _check();
      }
      _socket = socket;
      _diagnostics?.record(
        DiagnosticMediaStage.connect,
        DiagnosticResult.succeeded,
      );
      _subscription = socket.messages.listen(
        _message,
        onError: (Object _) => _failure(),
        onDone: _failure,
      );
      _stage = DiagnosticMediaStage.send;
      socket.send(
        TranslationRealtimeCodec.start(
          session.id,
          session.realtimeProvider,
          0,
          now().millisecondsSinceEpoch,
        ),
      );
      _stage = DiagnosticMediaStage.ready;
      if (!await _ready.future.timeout(readyTimeout)) {
        throw StateError('AppAudio not ready');
      }
      _check();
      _connected = true;
      _diagnostics?.record(
        DiagnosticMediaStage.ready,
        DiagnosticResult.succeeded,
      );
      _accountCheck = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!isCurrent()) unawaited(close().catchError((Object _) {}));
      });
    } catch (error) {
      _diagnostics?.record(
        _stage,
        (_closed && !_broken) || !isCurrent()
            ? DiagnosticResult.cancelled
            : DiagnosticResult.failed,
        reason: error is TimeoutException
            ? DiagnosticMediaReason.readyTimeout
            : DiagnosticMediaReason.deviceFailure,
      );
      await close();
      throw StateError('Translation AppAudio preparation failed');
    }
  }

  void _message(Object value) {
    if (!_current &&
        !(_closed && isCurrent() && !_events.isClosed && value is String)) {
      return;
    }
    try {
      final TranslationRealtimeMessage message;
      if (value is String && value.length <= 1024 * 1024) {
        message = TranslationRealtimeCodec.text(value);
      } else if (value is List<int> && value.length <= 1024 * 1024) {
        message = TranslationRealtimeCodec.binary(Uint8List.fromList(value));
      } else {
        throw const FormatException();
      }
      if (message.sessionId.isNotEmpty && message.sessionId != _sessionId) {
        return;
      }
      final event = message.event;
      if (_closed) {
        if (event is TranslationTranscriptDelta) _events.add(message);
        return;
      }
      if (event is TranslationReady) {
        if (event.kind == TranslationReadyKind.appAudio &&
            !_ready.isCompleted) {
          _diagnostics?.record(
            DiagnosticMediaStage.ready,
            DiagnosticResult.received,
          );
          _ready.complete(true);
        }
        if (event.kind == TranslationReadyKind.merchantAudio &&
            _captureStart == null) {
          _diagnostics?.record(
            DiagnosticMediaStage.merchantReady,
            DiagnosticResult.received,
          );
          _captureStart = _startCapture();
          unawaited(
            _captureStart!.then(
              (_) => _captureLoop(),
              onError: (Object _, StackTrace __) => _failure(
                stage: _captureStage,
                reason: DiagnosticMediaReason.deviceFailure,
              ),
            ),
          );
        }
      }
      if (event is TranslationAudio) {
        _enqueue(event);
        return;
      }
      _events.add(message);
      if (event is TranslationMediaError) {
        _diagnostics?.record(
          DiagnosticMediaStage.protocol,
          DiagnosticResult.failed,
          reason: DiagnosticMediaReason.providerError,
        );
      }
      if (event is TranslationEnded || event is TranslationMediaError) {
        unawaited(close().catchError((Object _) {}));
      }
    } catch (_) {
      _failure(reason: DiagnosticMediaReason.invalidFrame);
    }
  }

  Future<void> _startCapture() async {
    _check();
    await audio.start();
    _check();
    _diagnostics?.record(
      DiagnosticMediaStage.start,
      DiagnosticResult.succeeded,
    );
    _captureStage = DiagnosticMediaStage.speaker;
    await audio.setSpeaker(_speaker);
    _check();
    _diagnostics?.record(
      DiagnosticMediaStage.speaker,
      DiagnosticResult.succeeded,
    );
  }

  Future<void> _captureLoop() async {
    var stage = DiagnosticMediaStage.read;
    try {
      while (_current) {
        stage = DiagnosticMediaStage.read;
        final bytes = await audio.read();
        if (!_current) return;
        if (bytes == null ||
            bytes.isEmpty ||
            bytes.length.isOdd ||
            bytes.length > 640) {
          throw const FormatException();
        }
        if (!_readNoted) {
          _readNoted = true;
          _diagnostics?.record(
            DiagnosticMediaStage.read,
            DiagnosticResult.received,
          );
        }
        if (!_muted) {
          stage = DiagnosticMediaStage.send;
          _socket!.send(TranslationRealtimeCodec.media(bytes, 16000));
          if (!_sentNoted) {
            _sentNoted = true;
            _diagnostics?.record(
              DiagnosticMediaStage.send,
              DiagnosticResult.succeeded,
            );
          }
        }
      }
    } catch (error) {
      _failure(
        stage: stage,
        reason: error is FormatException
            ? DiagnosticMediaReason.invalidPcm
            : DiagnosticMediaReason.deviceFailure,
      );
    }
  }

  void _enqueue(TranslationAudio audio) {
    // v65 ignores translated output before merchant_audio_ready starts bridge.
    if (_captureStart == null ||
        (audio.sequence >= 0 && audio.sequence <= _lastSequence)) {
      return;
    }
    if (audio.sampleRate < 8000 ||
        audio.sampleRate > 48000 ||
        audio.pcm.isEmpty ||
        audio.pcm.length.isOdd) {
      throw const FormatException();
    }
    final seconds = audio.pcm.length / (audio.sampleRate * 2);
    if (_pendingSeconds + seconds > 2.00001) throw const FormatException();
    if (audio.sequence >= 0) _lastSequence = audio.sequence;
    _pendingSeconds += seconds;
    _queue.add(audio);
    if (!_pumping) {
      _pumping = true;
      unawaited(_playLoop());
    }
  }

  Future<void> _playLoop() async {
    try {
      await _captureStart;
      while (_current && _queue.isNotEmpty) {
        final frame = _queue.removeFirst();
        await audio.play(frame);
        if (!_current) return;
        if (!_playedNoted) {
          _playedNoted = true;
          _diagnostics?.record(
            DiagnosticMediaStage.play,
            DiagnosticResult.succeeded,
          );
        }
        _pendingSeconds -= frame.pcm.length / (frame.sampleRate * 2);
      }
    } catch (_) {
      _failure(
        stage: DiagnosticMediaStage.play,
        reason: DiagnosticMediaReason.deviceFailure,
      );
    } finally {
      _pumping = false;
    }
  }

  void _failure({
    DiagnosticMediaStage stage = DiagnosticMediaStage.protocol,
    DiagnosticMediaReason reason = DiagnosticMediaReason.transportError,
  }) {
    if (_closed || _broken) return;
    _diagnostics?.record(stage, DiagnosticResult.failed, reason: reason);
    _broken = true;
    if (!_ready.isCompleted) _ready.complete(false);
    if (_connected) {
      _events.addError(StateError('Translation AppAudio interrupted'));
    }
    unawaited(close().catchError((Object _) {}));
  }

  @override
  Future<void> setMuted(bool muted) async {
    _check();
    _muted = muted;
    _diagnostics?.record(
      DiagnosticMediaStage.microphone,
      DiagnosticResult.succeeded,
    );
  }

  @override
  Future<void> setSpeaker(bool enabled) async {
    _check();
    try {
      if (_captureStart != null) {
        await _captureStart;
        _check();
        await audio.setSpeaker(enabled);
        _check();
      }
      _speaker = enabled;
      _diagnostics?.record(
        DiagnosticMediaStage.speaker,
        _captureStart == null
            ? DiagnosticResult.received
            : DiagnosticResult.succeeded,
      );
    } catch (_) {
      _diagnostics?.record(
        DiagnosticMediaStage.speaker,
        (_closed && !_broken) || !isCurrent()
            ? DiagnosticResult.cancelled
            : DiagnosticResult.failed,
        reason: DiagnosticMediaReason.deviceFailure,
      );
      rethrow;
    }
  }

  @override
  Future<void> sendDtmf(String digit) =>
      Future.error(UnsupportedError('AppAudio DTMF unavailable'));
  @override
  Future<void> close() async {
    _closed = true;
    _queue.clear();
    _accountCheck?.cancel();
    if (!_ready.isCompleted) _ready.complete(false);
    await (_cleanup ??= _release());
    final lease = _lease;
    if (lease != null) {
      focus.release(lease);
      _lease = null;
    }
  }

  Future<void> _release() async {
    _diagnostics?.record(DiagnosticMediaStage.close, DiagnosticResult.started);
    var failed = false;
    try {
      await _subscription?.cancel();
      _subscription = null;
    } catch (_) {
      failed = true;
    }
    final socket = _socket;
    if (socket != null) {
      try {
        socket.send(TranslationRealtimeCodec.stop());
      } catch (_) {
        /* link may already be lost */
      }
      try {
        await socket.close();
        _socket = null;
      } catch (_) {
        failed = true;
      }
    }
    try {
      await audio.close();
    } catch (_) {
      failed = true;
    }
    if (failed) {
      _diagnostics?.record(
        DiagnosticMediaStage.close,
        DiagnosticResult.failed,
        reason: DiagnosticMediaReason.deviceFailure,
      );
      _cleanup = null;
      throw StateError('Translation AppAudio release failed');
    }
    unawaited(_events.close());
    _diagnostics?.record(
      DiagnosticMediaStage.close,
      DiagnosticResult.succeeded,
    );
  }
}
