import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';
import 'package:flutter/widgets.dart';
import '../../../../core/audio/audio_playback_focus.dart';
import '../../../../core/audio/focused_pcm_output.dart';
import '../../../../core/audio/pcm_output.dart';
import '../../../../core/audio/pcm_playback_queue.dart';
import '../../../../core/diagnostics/diagnostic_event.dart';
import '../../../../core/diagnostics/media_diagnostics.dart';
import '../../domain/voice/reply_speech_playback.dart';
import '../../domain/voice/reply_speech_start.dart';
import '../../domain/voice/speech_text_policy.dart';
import '../../domain/voice/voice_gateway_event.dart';
import '../../../settings/domain/network_availability.dart';
import 'task_tts_session.dart';
import 'task_tts_connection_owner.dart';

/// Serial synthesis can run ahead of playback; all sentences share one output.
class ConversationTtsStream
    implements ReplySpeechPlayback, ReplySpeechStartObserver {
  ConversationTtsStream({
    required this.endpoint,
    required this.createSession,
    this.connectionOwner,
    required PcmOutput output,
    required AudioPlaybackFocus focus,
    required this.isCurrent,
    required this.onChanged,
    Future<String>? speaker,
    this.readSpeaker,
    this.diagnostics,
    Stream<NetworkAvailability>? networkEvents,
    bool observeAppLifecycle = false,
  }) : _speaker = speaker {
    _playback = PcmPlaybackQueue(
      output: FocusedPcmOutput(
        output,
        focus,
        isCurrent: () => !_closed && isCurrent(),
        onInterrupted: () => unawaited(cancel()),
      ),
      sampleRateHz: 24000,
      onChanged: _changed,
    );
    if (networkEvents != null) {
      _networkSubscription = networkEvents.listen(_networkAvailabilityChanged);
    }
    if (connectionOwner?.networkAvailable == false) {
      _networkAvailabilityChanged(NetworkAvailability.unavailable);
    }
    if (observeAppLifecycle) {
      _lifecycle = AppLifecycleListener(onStateChange: handleAppLifecycle);
    }
  }
  Future<String>? _speaker;
  final Future<String> Function()? readSpeaker;
  final MediaDiagnostics? diagnostics;
  final Uri endpoint;
  final TaskTtsSession Function() createSession;
  final TaskTtsConnectionOwner? connectionOwner;
  TaskTtsLease? _lease;
  TaskTtsLease? _replyLease;
  final bool Function() isCurrent;
  final void Function() onChanged;
  late final PcmPlaybackQueue _playback;
  final _pending = Queue<String>();
  StreamSubscription<NetworkAvailability>? _networkSubscription;
  NetworkAvailability? _lastNetworkAvailability;
  Timer? _offlineTimer;
  AppLifecycleListener? _lifecycle;
  TaskTtsSession? _session;
  StreamSubscription<VoiceGatewayEvent>? _subscription;
  bool _sealed = false,
      _closed = false,
      _audio = false,
      _finishing = false,
      _requestActive = false;
  int _pendingCharacters = 0;

  @override
  void observeSpeechStart(DateTime observedAt, int elapsedMs) {
    if (_closed || _sealed || !isCurrent()) return;
    // Deferred emission preserves the original text time on this actual trace.
    diagnostics?.record(
      DiagnosticMediaStage.textObserved,
      DiagnosticResult.received,
      time: observedAt,
    );
    diagnostics?.record(
      DiagnosticMediaStage.sentenceEnqueued,
      DiagnosticResult.started,
      elapsedMs: elapsedMs,
    );
  }

  void _networkAvailabilityChanged(NetworkAvailability value) {
    // Native onListen emits a current-state snapshot, not a transition.
    // Unknown is absence of evidence and must not abort a healthy socket.
    if (_closed || _finishing || value == NetworkAvailability.unknown) return;
    final previous = _lastNetworkAvailability;
    _lastNetworkAvailability = value;
    if (previous == value) return;
    if (value == NetworkAvailability.unavailable) {
      _offlineTimer = Timer(const Duration(seconds: 15), () {
        if (_closed) return;
        if (!(_session?.active ?? false)) failures++;
        unawaited(_session?.invalidateTransport('network_changed'));
        unawaited(_playback.fail('tts_network_timeout'));
      });
      _session?.setNetworkAvailable(false);
    } else {
      _offlineTimer?.cancel();
      _offlineTimer = null;
      _session?.setNetworkAvailable(true);
      _next();
    }
  }

  /// Losing foreground ownership cancels this reply without reporting a
  /// transport failure or replaying its remaining sentences on resume.
  void handleAppLifecycle(AppLifecycleState state) {
    if (_closed || phase == ReplySpeechPhase.completed) return;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      unawaited(cancel());
    }
  }

  @override
  int failures = 0;
  @override
  int get queuedBytes => _playback.queuedBytes;
  @override
  bool get synthesizing => _requestActive;
  @override
  bool get hasPendingText => _pending.isNotEmpty;
  @override
  ReplySpeechPhase get phase => switch (_playback.phase) {
    PcmPlaybackPhase.accepting => ReplySpeechPhase.accepting,
    PcmPlaybackPhase.draining => ReplySpeechPhase.draining,
    PcmPlaybackPhase.drained => ReplySpeechPhase.completed,
    PcmPlaybackPhase.cancelled => ReplySpeechPhase.cancelled,
    PcmPlaybackPhase.failed => ReplySpeechPhase.failed,
  };

  @override
  bool enqueue(String text) {
    if (_closed || _sealed || !isCurrent()) {
      diagnostics?.record(
        DiagnosticMediaStage.queueAdmission,
        DiagnosticResult.cancelled,
        reason: _closed
            ? DiagnosticMediaReason.streamClosed
            : _sealed
            ? DiagnosticMediaReason.streamSealed
            : DiagnosticMediaReason.staleReply,
      );
      return false;
    }
    final cleaned = SpeechTextPolicy.clean(text);
    if (cleaned.isEmpty) {
      diagnostics?.record(
        DiagnosticMediaStage.queueAdmission,
        DiagnosticResult.cancelled,
        reason: DiagnosticMediaReason.emptyText,
      );
      return false;
    }
    if (_pendingCharacters + cleaned.length > 65536) {
      diagnostics?.record(
        DiagnosticMediaStage.queueAdmission,
        DiagnosticResult.failed,
        reason: DiagnosticMediaReason.textCapacity,
      );
      unawaited(_playback.fail('tts_text_capacity'));
      return false;
    }
    _pendingCharacters += cleaned.length;
    _pending.add(cleaned);
    diagnostics?.record(
      DiagnosticMediaStage.queueAdmission,
      DiagnosticResult.succeeded,
    );
    _next();
    return true;
  }

  void _next() {
    if (_closed || _finishing || _requestActive) return;
    if (!isCurrent()) {
      unawaited(cancel());
      return;
    }
    if (_lastNetworkAvailability == NetworkAvailability.unavailable) return;
    if (_pending.isEmpty) {
      if (_sealed) {
        _finishing = true;
        try {
          if (_audio) _playback.add(Uint8List(2880));
          _playback.complete();
          unawaited(_closeSession());
        } catch (_) {
          unawaited(_playback.fail('tts_output_capacity'));
        }
      }
      return;
    }
    final text = _pending.removeFirst();
    _pendingCharacters -= text.length;
    diagnostics?.record(
      DiagnosticMediaStage.queueDequeued,
      DiagnosticResult.started,
    );
    final session = _session ??= _acquireSession();
    _subscription ??= session.events.listen(
      (event) => _event(session, event),
      onError: (Object _) => _ended(session, failed: true),
      onDone: () {
        if (_requestActive) _ended(session, failed: true);
      },
    );
    _requestActive = true;
    onChanged();
    unawaited(
      (_speaker ??= _resolveSpeaker())
          .then<void>((speaker) async {
            if (_closed || _session != session || !_requestActive) return;
            if (!isCurrent()) {
              await cancel();
              return;
            }
            diagnostics?.record(
              DiagnosticMediaStage.speakerResolved,
              DiagnosticResult.succeeded,
            );
            await session.start(
              endpoint,
              text: text,
              speaker: speaker,
              requestDiagnostics: diagnostics,
            );
          })
          .catchError((Object _) => _ended(session, failed: true)),
    );
  }

  Future<String> _resolveSpeaker() async =>
      await (readSpeaker?.call() ??
          Future.value(_lease?.speaker ?? SpeechTextPolicy.speaker));

  TaskTtsSession _acquireSession() {
    final owner = connectionOwner;
    if (owner == null) return createSession();
    _lease = owner.acquire(onInvalidated: () => unawaited(cancel()));
    _replyLease = _lease;
    return _lease!.session;
  }

  Future<void> _closeSession() async {
    final session = _session;
    final subscription = _subscription;
    _session = null;
    _subscription = null;
    await Future.wait([
      if (session != null) _releaseSession(session),
      if (subscription != null) subscription.cancel(),
    ]);
  }

  Future<void> _releaseSession(
    TaskTtsSession session, {
    bool cancelled = false,
  }) async {
    final lease = _lease;
    _lease = null;
    if (lease == null) {
      await session.cancel();
    } else {
      lease.release(cancelled: cancelled);
    }
  }

  void _event(TaskTtsSession session, VoiceGatewayEvent event) {
    if (_closed || _session != session) return;
    if (!isCurrent()) {
      unawaited(cancel());
      return;
    }
    try {
      if (event is VoicePcmChunk) {
        if (!_audio) {
          _audio = true;
          _playback.add(Uint8List(15360));
        }
        _playback.add(event.bytes);
      } else if (event is VoiceSynthesisComplete) {
        _ended(session);
      } else if (event is VoiceGatewayFailure) {
        _ended(session, failed: true);
      }
    } catch (_) {
      unawaited(_playback.fail('tts_output_failed'));
    }
  }

  void _ended(TaskTtsSession session, {bool failed = false}) {
    if (_closed || _session != session || !_requestActive) return;
    _requestActive = false;
    if (failed) {
      failures++;
    }
    // Completion may be emitted synchronously by the source; leave its stack.
    scheduleMicrotask(() {
      if (!_closed) _next();
    });
    onChanged();
  }

  void _changed() {
    if (phase == ReplySpeechPhase.completed ||
        phase == ReplySpeechPhase.cancelled ||
        phase == ReplySpeechPhase.failed) {
      _replyLease?.detach();
      _replyLease = null;
    }
    if (phase == ReplySpeechPhase.failed && !_closed) {
      _closed = true;
      _pending.clear();
      _pendingCharacters = 0;
      _requestActive = false;
      final session = _session;
      if (session != null) unawaited(_releaseSession(session, cancelled: true));
      _session = null;
      unawaited(_subscription?.cancel());
      _subscription = null;
      unawaited(_disposeLifecycle());
    }
    onChanged();
  }

  Future<void> _disposeLifecycle() async {
    _offlineTimer?.cancel();
    _offlineTimer = null;
    final subscription = _networkSubscription;
    _networkSubscription = null;
    _lifecycle?.dispose();
    _lifecycle = null;
    await subscription?.cancel();
  }

  @override
  void complete() {
    if (_closed || _sealed) return;
    _sealed = true;
    _next();
  }

  @override
  Future<void> cancel() async {
    _closed = true;
    _replyLease?.detach();
    _replyLease = null;
    _pending.clear();
    _pendingCharacters = 0;
    _requestActive = false;
    final stop = _playback.stop();
    final session = _session;
    final subscription = _subscription;
    _session = null;
    _subscription = null;
    await Future.wait([
      stop,
      if (session != null) _releaseSession(session, cancelled: true),
      if (subscription != null) subscription.cancel(),
    ]);
    await _disposeLifecycle();
  }
}
