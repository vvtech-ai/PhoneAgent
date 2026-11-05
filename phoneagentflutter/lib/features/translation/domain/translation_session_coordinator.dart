import 'translation_call_failure.dart';
import '../../../core/diagnostics/diagnostic_event.dart';
import 'translation_preparation_diagnostics.dart';
import 'translation_preparation_policy.dart';
import 'dart:async';
import 'translation_backend_session.dart';
import 'translation_media_port.dart';
import 'translation_service_catalog.dart';
import 'translation_realtime_event.dart';

enum TranslationSessionStage {
  idle,
  checkingLanguages,
  creating,
  preparingMedia,
  dialing,
  ringing,
  connected,
  translating,
  ending,
  ended,
  failed,
}

/// Single-use session. Owns ordering, never audio/UI or automatic call replay.
class TranslationSessionCoordinator {
  TranslationSessionCoordinator({
    required this.backend,
    required this.mediaFactory,
    required this.loadLanguages,
    required this.onStage,
    this.onEnvironment,
    this.diagnostics,
    this.onTranscript,
    this.readyTimeout = const Duration(seconds: 10),
    Future<void> Function(Duration)? wait,
    DateTime Function()? now,
  }) : wait = wait ?? Future<void>.delayed,
       now = now ?? DateTime.now;
  final DiagnosticSink? diagnostics;
  final TranslationBackendRepository backend;
  final TranslationMediaFactory mediaFactory;
  final Future<TranslationServiceCatalog> Function() loadLanguages;
  final void Function(TranslationSessionStage stage, String error) onStage;
  final void Function(Map<String, Object?> environment)? onEnvironment;
  final void Function(TranslationRealtimeEvent event)? onTranscript;
  final Duration readyTimeout;
  final Future<void> Function(Duration) wait;
  final DateTime Function() now;
  TranslationBackendSession? _session;
  TranslationCreateRequest? _request;
  TranslationMediaPort? _media, _drainingMedia;
  StreamSubscription<TranslationRealtimeMessage>? _subscription;
  Timer? _drainTimer;
  Completer<bool>? _preparationFailure;
  Future<void>? _work, _stopWork, _cleanupWork;
  bool _ending = false, _disposed = false, _cleanupFailed = false;
  bool _connected = false;
  bool _desiredMuted = false, _desiredSpeaker = false;
  int _controlRevision = 0;
  String _terminalError = '';
  TranslationSessionStage stage = TranslationSessionStage.idle;
  TranslationBackendSession? get session => _session;
  bool get cleanupUnconfirmed => _cleanupFailed;

  Future<void> start(TranslationCreateRequest request) {
    if (_work != null) return _work!;
    if (_ending || _disposed) return Future.value();
    request.toJson();
    _request = request;
    return _work = Future<void>.microtask(() => _run(request));
  }

  Future<void> _run(TranslationCreateRequest request) async {
    try {
      if (_ending) return;
      _emit(TranslationSessionStage.checkingLanguages);
      final catalog = await loadLanguages();
      if (_ending) return;
      request = request.withLanguages(
        resolveTranslationLanguage(request.userLanguage, catalog),
        resolveTranslationLanguage(request.merchantLanguage, catalog),
      );
      _request = request;
      _emit(TranslationSessionStage.creating);
      if (_ending) return;
      _session = await backend.create(request);
      if (_ending) return;
      _environment(_session!.environment);
      _emit(TranslationSessionStage.preparingMedia);
      if (!await _prepare(_session!) || _ending) {
        if (!_ending) throw const TranslationBackendFailure('MEDIA_NOT_READY');
        return;
      }
      _emit(TranslationSessionStage.dialing);
      final result = await _startMerchant(_session!, request);
      if (_ending) return;
      _environment(result.environment);
      if (!result.started) throw const TranslationBackendFailure('NOT_STARTED');
      // Started means provider accepted dialing, never proof of connection.
      if (!_connected) _emit(TranslationSessionStage.ringing);
    } catch (error) {
      recordTranslationPreparation(
        diagnostics,
        _diagnosticStage(stage),
        DiagnosticResult.failed,
        error: error,
      );
      if (error is TranslationBackendFailure &&
          error.code == 'INVALID_RESPONSE_CLEANUP_FAILED') {
        _cleanupFailed = true;
      }
      if (!_ending) {
        _ending = true;
        _terminalError = translationPreparationMessage(
          _diagnosticStage(stage),
          error,
        );
        await _cleanup();
        _emit(TranslationSessionStage.failed, _terminalError);
      }
    } finally {
      if (_ending) await _cleanup();
    }
  }

  Future<bool> _prepare(TranslationBackendSession session) async {
    final choices = [
      if (session.mediaTransport.toLowerCase() == 'livekit' &&
          session.liveKit != null)
        TranslationMediaTransport.liveKit,
      if (session.appAudioWsUrl.isNotEmpty) TranslationMediaTransport.websocket,
    ];
    for (final choice in choices) {
      if (_ending) return false;
      final media = mediaFactory(choice);
      _media = media;
      final failure = Completer<bool>();
      _preparationFailure = failure;
      try {
        if (media is TranslationInteractiveMediaPort) {
          _subscription = media.events.listen(
            (event) => _message(media, event),
            onError: (Object error) => _linkLost(media),
            onDone: () => _linkLost(media),
          );
        }
        final ready = await Future.any<bool>([
          media.connect(session).then((_) => true),
          failure.future,
        ]).timeout(readyTimeout);
        if (!ready || failure.isCompleted) {
          throw const TranslationBackendFailure('MEDIA_NOT_READY');
        }
        if (media is TranslationInteractiveMediaPort) {
          var applied = false, mutedApplied = false, speakerApplied = false;
          for (var attempt = 0; attempt < 16 && !_ending; attempt++) {
            final revision = _controlRevision;
            final muted = _desiredMuted, speaker = _desiredSpeaker;
            if (muted != mutedApplied) {
              if (!await _prepareControl(
                () => media.setMuted(muted),
                failure,
              )) {
                return false;
              }
              mutedApplied = muted;
              if (_ending) return false;
            }
            if (speaker != speakerApplied) {
              if (!await _prepareControl(
                () => media.setSpeaker(speaker),
                failure,
              )) {
                return false;
              }
              speakerApplied = speaker;
              if (_ending) return false;
            }
            if (revision == _controlRevision) {
              applied = true;
              break;
            }
          }
          if (!applied || failure.isCompleted) {
            throw const TranslationBackendFailure('MEDIA_NOT_READY');
          }
        }
        _preparationFailure = null;
        return !_ending;
      } catch (error) {
        recordTranslationPreparation(
          diagnostics,
          choice == TranslationMediaTransport.liveKit
              ? 'overseasLiveKit'
              : 'overseasWebsocket',
          DiagnosticResult.failed,
          error: error,
        );
        if (identical(_media, media)) {
          await _closeMedia();
          if (_cleanupFailed) rethrow;
        }
      }
    }
    return false;
  }

  Future<bool> _prepareControl(
    Future<void> Function() action,
    Completer<bool> failure,
  ) => Future.any<bool>([
    action().then((_) => true),
    failure.future,
  ]).timeout(readyTimeout);

  Future<TranslationMerchantResult> _startMerchant(
    TranslationBackendSession session,
    TranslationCreateRequest request,
  ) async {
    final deadline = now().add(const Duration(seconds: 10));
    // Count also bounds an injected/non-monotonic wall clock.
    for (var attempt = 0; ; attempt++) {
      if (_ending) throw const TranslationBackendFailure('CANCELLED');
      try {
        return await backend.startMerchant(session, request);
      } on TranslationBackendFailure catch (error) {
        _environment(error.environment);
        if (!error.mediaNotReady ||
            _ending ||
            attempt >= 20 ||
            !now().isBefore(deadline)) {
          rethrow;
        }
        await wait(const Duration(milliseconds: 500));
      }
    }
  }

  Future<void> stop() {
    if (_stopWork != null) return _stopWork!;
    if (stage == TranslationSessionStage.ended ||
        stage == TranslationSessionStage.failed) {
      return _cleanup();
    }
    _ending = true;
    _stopWork = Future<void>.microtask(_stop);
    _emit(TranslationSessionStage.ending);
    return _stopWork!;
  }

  void _message(
    TranslationMediaPort owner,
    TranslationRealtimeMessage message,
  ) {
    if (_ending || _disposed) {
      if (identical(owner, _drainingMedia) &&
          (message.sessionId.isEmpty || message.sessionId == _session?.id) &&
          message.event is TranslationTranscriptDelta) {
        onTranscript?.call(message.event);
      }
      return;
    }
    if (!identical(owner, _media)) return;
    if (message.sessionId.isNotEmpty && message.sessionId != _session?.id) {
      return;
    }
    _environment(message.environment);
    final event = message.event;
    if (event is TranslationEnded) {
      unawaited(stop());
    } else if (event is TranslationMediaError) {
      _terminalError = translationCallFailureMessage(event.code);
      unawaited(stop());
    } else if (event is TranslationConnected) {
      _markConnected();
    } else if (event is TranslationTranscriptDelta ||
        event is TranslationConnectPrompt) {
      if (event is TranslationTranscriptDelta &&
          event.sourceLeg == 'merchant' &&
          event.text.trim().isNotEmpty) {
        _markConnected();
      }
      onTranscript?.call(event);
    }
  }

  void _markConnected() {
    if (_connected ||
        (stage != TranslationSessionStage.dialing &&
            stage != TranslationSessionStage.ringing)) {
      return;
    }
    _connected = true;
    _emit(TranslationSessionStage.connected);
    _emit(TranslationSessionStage.translating);
  }

  void _linkLost(TranslationMediaPort owner) {
    if (identical(owner, _drainingMedia)) {
      _drainingMedia = null;
      _drainTimer?.cancel();
      _drainTimer = null;
      return;
    }
    if (_ending || _disposed || !identical(owner, _media)) return;
    final failure = _preparationFailure;
    if (failure != null) {
      if (!failure.isCompleted) failure.complete(false);
      return;
    }
    _terminalError = translationCallFailureMessage('NETWORK');
    unawaited(stop());
  }

  bool get supportsDtmf =>
      _media is TranslationInteractiveMediaPort &&
      (_media as TranslationInteractiveMediaPort).supportsDtmf;
  bool get _preparing => const {
    TranslationSessionStage.idle,
    TranslationSessionStage.checkingLanguages,
    TranslationSessionStage.creating,
    TranslationSessionStage.preparingMedia,
  }.contains(stage);
  Future<bool> setMuted(bool value) async {
    if (_ending || _disposed) return false;
    if (_preparing) {
      _desiredMuted = value;
      _controlRevision++;
      return true;
    }
    final accepted = await _control((port) => port.setMuted(value));
    if (accepted) _desiredMuted = value;
    return accepted;
  }

  Future<bool> setSpeaker(bool value) async {
    if (_ending || _disposed) return false;
    if (_preparing) {
      _desiredSpeaker = value;
      _controlRevision++;
      return true;
    }
    final accepted = await _control((port) => port.setSpeaker(value));
    if (accepted) _desiredSpeaker = value;
    return accepted;
  }

  Future<bool> sendDtmf(String digit) {
    if (!supportsDtmf || !RegExp(r'^[0-9*#]$').hasMatch(digit)) {
      return Future.value(false);
    }
    return _control((port) => port.sendDtmf(digit));
  }

  Future<bool> _control(
    Future<void> Function(TranslationInteractiveMediaPort) action,
  ) async {
    final media = _media;
    if (_ending ||
        _disposed ||
        media is! TranslationInteractiveMediaPort ||
        stage == TranslationSessionStage.preparingMedia) {
      return false;
    }
    try {
      await action(media);
      return !_ending && !_disposed && identical(media, _media);
    } catch (_) {
      return false;
    }
  }

  Future<void> _cancelSubscription() async {
    final subscription = _subscription;
    _subscription = null;
    await subscription?.cancel();
  }

  Future<void> _stop() async {
    // Stop media immediately, but serialize backend hangup after in-flight start.
    await _closeMedia();
    await _work;
    await _cleanup();
    _emit(
      _cleanupFailed || _terminalError.isNotEmpty
          ? TranslationSessionStage.failed
          : TranslationSessionStage.ended,
      _terminalError.isNotEmpty
          ? _terminalError
          : _cleanupFailed
          ? translationCallFailureMessage('UNKNOWN')
          : '',
    );
  }

  Future<void> _closeMedia() async {
    final media = _media;
    _media = null;
    final failure = _preparationFailure;
    _preparationFailure = null;
    if (failure != null && !failure.isCompleted) failure.complete(false);
    try {
      if (_ending && media != null) {
        // Stop hardware now; drain queued subtitle events without retaining
        // audio ownership. The account/controller restricts frozen keys.
        final subscription = _subscription;
        _subscription = null;
        _drainingMedia = media;
        _drainTimer = Timer(const Duration(milliseconds: 500), () {
          if (identical(_drainingMedia, media)) _drainingMedia = null;
          unawaited(
            subscription?.cancel().catchError((Object _) {}) ??
                Future<void>.value(),
          );
        });
      } else {
        await _cancelSubscription();
      }
    } catch (_) {
      _cleanupFailed = true;
    }
    try {
      await media?.close();
    } catch (_) {
      _cleanupFailed = true;
    }
  }

  Future<void> _cleanup() => _cleanupWork ??= _release();
  Future<void> _release() async {
    await _closeMedia();
    final session = _session, request = _request;
    if (session != null && request != null) {
      try {
        await backend.hangup(session, request.userId);
      } catch (_) {
        _cleanupFailed = true;
      }
    }
  }

  void _environment(Map<String, Object?> value) {
    if (!_disposed && !_ending && value.isNotEmpty) onEnvironment?.call(value);
  }

  void _emit(TranslationSessionStage value, [String error = '']) {
    if (_ending &&
        value != TranslationSessionStage.ending &&
        value != TranslationSessionStage.ended &&
        value != TranslationSessionStage.failed) {
      return;
    }
    recordTranslationPreparation(
      diagnostics,
      _diagnosticStage(value),
      DiagnosticResult.received,
    );
    stage = value;
    if (!_disposed) onStage(value, error);
  }

  static String _diagnosticStage(TranslationSessionStage value) =>
      switch (value) {
        TranslationSessionStage.checkingLanguages => 'overseasLanguages',
        TranslationSessionStage.creating => 'overseasCreate',
        TranslationSessionStage.preparingMedia => 'overseasMedia',
        TranslationSessionStage.dialing => 'overseasDial',
        TranslationSessionStage.ringing => 'overseasRinging',
        TranslationSessionStage.connected => 'overseasConnected',
        TranslationSessionStage.translating => 'overseasTranslating',
        TranslationSessionStage.ending => 'overseasEnding',
        TranslationSessionStage.ended => 'overseasEnded',
        TranslationSessionStage.failed => 'overseasFailed',
        TranslationSessionStage.idle => 'unknown',
      };

  Future<void> dispose() {
    _disposed = true;
    return stop();
  }
}
