import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import '../../../core/diagnostics/diagnostic_event.dart';
import '../../../core/diagnostics/media_diagnostics.dart';
import '../../../core/audio/audio_playback_focus.dart';
import '../../../core/audio/audio_resource_coordinator.dart';
import '../../conversation/domain/tools/conversation_permission.dart';
import '../domain/translation_backend_session.dart';
import '../domain/translation_livekit_room.dart';
import '../domain/translation_media_port.dart';
import '../domain/translation_realtime_event.dart';
import 'translation_realtime_codec.dart';

/// Shared v65 double-ready and lifetime rules. The SDK is behind roomFactory.
class LiveKitTranslationMedia implements TranslationInteractiveMediaPort {
  LiveKitTranslationMedia({
    required this.roomFactory,
    required this.permissions,
    required this.focus,
    required this.isCurrent,
    this.readyTimeout = const Duration(seconds: 10),
    this.diagnostics,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;
  final TranslationLiveKitRoom Function() roomFactory;
  final ConversationPermissionSource permissions;
  final AudioPlaybackFocus focus;
  final bool Function() isCurrent;
  final Duration readyTimeout;
  final MediaDiagnostics? diagnostics;
  MediaDiagnostics? _diagnostics;
  DiagnosticMediaStage _stage = DiagnosticMediaStage.connect;
  final DateTime Function() now;
  final _events = StreamController<TranslationRealtimeMessage>(
    sync: true,
    onCancel: () => Future<void>.microtask(() {}),
  );
  final _ready = Completer<bool>();
  TranslationLiveKitRoom? _room;
  StreamSubscription<TranslationRoomEvent>? _subscription;
  AudioLease? _lease;
  Future<void>? _startup, _cleanup;
  String _sessionId = '';
  bool _closed = false,
      _used = false,
      _roomReady = false,
      _realtimeReady = false,
      _connected = false,
      _broken = false;
  bool get _current => !_closed && !_broken && isCurrent();
  @override
  Stream<TranslationRealtimeMessage> get events => _events.stream;
  @override
  bool get supportsDtmf => true;
  void _check() {
    if (!_current) throw StateError('Translation media cancelled');
  }

  @override
  Future<void> connect(TranslationBackendSession session) async {
    _check();
    if (_used) throw StateError('Translation media already used');
    _used = true;
    _diagnostics = diagnostics?.withSession(session.id);
    _diagnostics?.record(
      DiagnosticMediaStage.connect,
      DiagnosticResult.started,
    );
    final ticket = session.liveKit;
    final uri = ticket == null ? null : Uri.tryParse(ticket.url);
    if (ticket == null ||
        ticket.token.trim().isEmpty ||
        session.id.trim().isEmpty ||
        uri == null ||
        !const {'wss', 'https'}.contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment) {
      _diagnostics?.record(
        DiagnosticMediaStage.protocol,
        DiagnosticResult.failed,
        reason: DiagnosticMediaReason.invalidFrame,
      );
      throw StateError('Invalid translation room ticket');
    }
    _sessionId = session.id;
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
        owner: 'translation-livekit',
        stop: (_) => close(),
        isCurrent: () => _current,
        interruptible: false,
      );
      _check();
      _stage = DiagnosticMediaStage.start;
      final room = _room = roomFactory();
      _subscription = room.events.listen(
        _event,
        onError: (Object _) => _failure(),
        onDone: _failure,
      );
      _startup = _startRoom(room, ticket);
      await _startup;
      _stage = DiagnosticMediaStage.ready;
      if (!await _ready.future.timeout(readyTimeout)) {
        throw StateError('Translation room not ready');
      }
      _check();
      _connected = true;
      _diagnostics?.record(
        DiagnosticMediaStage.ready,
        DiagnosticResult.succeeded,
      );
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
      throw StateError('Translation LiveKit preparation failed');
    }
  }

  Future<void> _startRoom(
    TranslationLiveKitRoom room,
    TranslationLiveKitConnection ticket,
  ) async {
    _stage = DiagnosticMediaStage.connect;
    await room.connect(ticket.url, ticket.token);
    _check();
    _diagnostics?.record(
      DiagnosticMediaStage.connect,
      DiagnosticResult.succeeded,
    );
    _stage = DiagnosticMediaStage.speaker;
    await room.speaker(false);
    _check();
    _stage = DiagnosticMediaStage.microphone;
    await room.microphone(true);
    _check();
    _roomReady = true;
    _stage = DiagnosticMediaStage.roomReady;
    // Publish even if realtime_ready arrived before room initialization.
    await room.publish(
      Uint8List.fromList(
        utf8.encode(TranslationRealtimeCodec.roomReady(_sessionId)),
      ),
      TranslationRealtimeCodec.controlTopic,
    );
    _check();
    _diagnostics?.record(
      DiagnosticMediaStage.roomReady,
      DiagnosticResult.succeeded,
    );
    _signalReady();
  }

  void _signalReady() {
    if (_roomReady && _realtimeReady && !_ready.isCompleted) {
      _ready.complete(true);
    }
  }

  void _event(TranslationRoomEvent event) {
    if (!_current &&
        !(_closed &&
            isCurrent() &&
            !_events.isClosed &&
            event is TranslationRoomData)) {
      return;
    }
    if (event is TranslationRoomDisconnected) {
      _failure();
      return;
    }
    if (event is! TranslationRoomData) return;
    final topic = event.topic?.trim() ?? '';
    if (topic.isNotEmpty && topic != TranslationRealtimeCodec.controlTopic) {
      return;
    }
    try {
      if (event.bytes.length > 1024 * 1024) throw const FormatException();
      final message = TranslationRealtimeCodec.text(utf8.decode(event.bytes));
      if (message.sessionId.isNotEmpty && message.sessionId != _sessionId) {
        return;
      }
      if (_closed) {
        if (message.event is TranslationTranscriptDelta) _events.add(message);
        return;
      }
      if (message.event case TranslationReady(
        kind: TranslationReadyKind.realtime,
      )) {
        if (!_realtimeReady) {
          _diagnostics?.record(
            DiagnosticMediaStage.ready,
            DiagnosticResult.received,
          );
        }
        _realtimeReady = true;
        _signalReady();
      }
      if (message.event is TranslationMediaError) {
        _diagnostics?.record(
          DiagnosticMediaStage.protocol,
          DiagnosticResult.failed,
          reason: DiagnosticMediaReason.providerError,
        );
      }
      _events.add(message);
    } catch (_) {
      _failure(DiagnosticMediaReason.invalidFrame);
    }
  }

  void _failure([
    DiagnosticMediaReason reason = DiagnosticMediaReason.transportError,
  ]) {
    if (!_current) return;
    _diagnostics?.record(
      DiagnosticMediaStage.protocol,
      DiagnosticResult.failed,
      reason: reason,
    );
    _broken = true;
    if (!_ready.isCompleted) _ready.complete(false);
    if (_connected) {
      _events.addError(StateError('Translation media disconnected'));
    }
  }

  Future<void> _control(
    DiagnosticMediaStage stage,
    Future<void> Function(TranslationLiveKitRoom) action,
  ) async {
    _check();
    final room = _room;
    if (!_connected || room == null) {
      throw StateError('Translation media not ready');
    }
    try {
      await action(room);
      _check();
      _diagnostics?.record(stage, DiagnosticResult.succeeded);
    } catch (_) {
      _diagnostics?.record(
        stage,
        (_closed && !_broken) || !isCurrent()
            ? DiagnosticResult.cancelled
            : DiagnosticResult.failed,
        reason: DiagnosticMediaReason.deviceFailure,
      );
      throw StateError('Translation media control failed');
    }
  }

  @override
  Future<void> setMuted(bool muted) => _control(
    DiagnosticMediaStage.microphone,
    (room) => room.microphone(!muted),
  );
  @override
  Future<void> setSpeaker(bool enabled) =>
      _control(DiagnosticMediaStage.speaker, (room) => room.speaker(enabled));
  @override
  Future<void> sendDtmf(String digit) => _control(
    DiagnosticMediaStage.dtmf,
    (room) => room.publish(
      Uint8List.fromList(
        utf8.encode(
          TranslationRealtimeCodec.dtmf(
            _sessionId,
            digit,
            now().millisecondsSinceEpoch,
          ),
        ),
      ),
      TranslationRealtimeCodec.controlTopic,
    ),
  );
  @override
  Future<void> close() async {
    _closed = true;
    if (!_ready.isCompleted) _ready.complete(false);
    await (_cleanup ??= _release());
    // A lease can be granted just as cancellation happens.
    final lease = _lease;
    if (lease != null) {
      focus.release(lease);
      _lease = null;
    }
  }

  Future<void> _release() async {
    _diagnostics?.record(DiagnosticMediaStage.close, DiagnosticResult.started);
    try {
      // Signal shutdown before awaiting startup: a cancellable room connect
      // may itself require close() to settle its pending future.
      await _room?.close();
      try {
        await _startup;
      } catch (_) {
        /* still must close the room */
      }
      await _subscription?.cancel();
      _subscription = null;
      unawaited(_events.close());
      _diagnostics?.record(
        DiagnosticMediaStage.close,
        DiagnosticResult.succeeded,
      );
    } catch (_) {
      _diagnostics?.record(
        DiagnosticMediaStage.close,
        DiagnosticResult.failed,
        reason: DiagnosticMediaReason.deviceFailure,
      );
      _cleanup = null;
      throw StateError('Translation media release failed');
    }
  }
}
