import '../../domain/translation_call_environment.dart';
import '../../domain/translation_connected_duration.dart';
import '../../domain/translation_transcript_tail.dart';
import '../../../../core/diagnostics/diagnostic_event.dart';
import 'dart:async';
import 'translation_call_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/translation_backend_session.dart';
import '../../domain/translation_call_view.dart';
import '../../domain/translation_media_port.dart';
import '../../domain/translation_service_catalog.dart';
import '../../domain/translation_session_coordinator.dart';
import '../../domain/translation_transcript_accumulator.dart';
import '../../domain/translation_call_finished.dart';
import '../../domain/translation_archive.dart';

/// Shared production state owner; previews replace only backend/media ports.
class TranslationSessionController extends StateNotifier<TranslationCallView>
    implements TranslationCallController {
  TranslationSessionController({
    required TranslationBackendRepository backend,
    required TranslationMediaFactory mediaFactory,
    required Future<TranslationServiceCatalog> Function() loadLanguages,
    required this.request,
    TranslationCallContext? context,
    this.onFinished,
    DiagnosticSink? diagnostics,
    this.onArchive,
    this.onReleased,
    this.onDtmfInput,
    DateTime Function()? now,
  }) : context = context ?? TranslationCallContext.create(),
       _now = now ?? DateTime.now,
       super(const TranslationCallView()) {
    _tail = TranslationTranscriptTail(_now);
    _transcripts = TranslationTranscriptAccumulator(
      request.userLanguage,
      request.merchantLanguage,
    );
    coordinator = TranslationSessionCoordinator(
      diagnostics: diagnostics,
      backend: backend,
      mediaFactory: mediaFactory,
      loadLanguages: loadLanguages,
      onStage: _stage,
      onEnvironment: (patch) {
        if (!mounted || state.terminal || state.stopping) return;
        final next = state.environment.apply(patch);
        _subtitleUnavailable =
            next.overall == TranslationEnvironmentState.unavailable;
        if (!identical(next, state.environment)) {
          state = state.copy(environment: next);
        }
      },
      onTranscript: (event) {
        if (_subtitleUnavailable) return;
        _transcripts.apply(event, accepts: _tail.accepts);
        if (mounted) {
          state = state.copy(transcripts: _tail.snapshot(_transcripts.items));
        }
        _archive();
      },
    );
  }
  final TranslationCreateRequest request;
  final TranslationCallContext context;
  final void Function(TranslationCallFinished)? onFinished;
  final void Function(TranslationArchiveEntry)? onArchive;
  final void Function()? onReleased;
  final void Function()? onDtmfInput;
  int? _archiveEndedAt;
  TranslationCallFinished? finished;
  DateTime? _startedAt;
  final DateTime Function() _now;
  late final TranslationSessionCoordinator coordinator;
  late final TranslationTranscriptAccumulator _transcripts;
  late final TranslationTranscriptTail _tail;
  Timer? _timer;
  bool _subtitleUnavailable = false;
  DateTime? _connectedAt;
  @override
  TranslationCallView get snapshot => state;
  @override
  Future<void> start() {
    _startedAt ??= _now();
    _archive();
    return coordinator.start(request);
  }

  void _stage(TranslationSessionStage value, String error) {
    if (!mounted) return;
    if (value == TranslationSessionStage.ending) {
      _tail.freeze(_transcripts.items);
      _timer?.cancel();
      state = state.copy(stopping: true, error: '正在结束通话');
      _archive();
      return;
    }
    final phase = switch (value) {
      TranslationSessionStage.idle ||
      TranslationSessionStage.checkingLanguages ||
      TranslationSessionStage.creating ||
      TranslationSessionStage.preparingMedia => TranslationPhase.preflight,
      TranslationSessionStage.dialing => TranslationPhase.dialing,
      TranslationSessionStage.ringing => TranslationPhase.ringing,
      TranslationSessionStage.connected => TranslationPhase.connected,
      TranslationSessionStage.translating => TranslationPhase.translating,
      TranslationSessionStage.ended => TranslationPhase.ended,
      TranslationSessionStage.failed => TranslationPhase.failed,
      TranslationSessionStage.ending => state.phase,
    };
    if (_connectedAt == null &&
        (phase == TranslationPhase.connected ||
            phase == TranslationPhase.translating)) {
      _connectedAt = _now();
    }
    if (phase == TranslationPhase.ended || phase == TranslationPhase.failed) {
      _tail.freeze(_transcripts.items, terminal: true);
      // Capture before a Finished listener can dispose the call owner.
      _archive(terminal: true);
    }
    // Capture before listeners can synchronously pop/dispose this route.
    if ((phase == TranslationPhase.ended || phase == TranslationPhase.failed) &&
        finished == null &&
        _startedAt != null) {
      finished = TranslationCallFinished(
        context: context,
        accountId: request.userId,
        phone: request.phone,
        callerLanguage: request.userLanguage,
        peerLanguage: request.merchantLanguage,
        startedAtMillis: _startedAt!.millisecondsSinceEpoch,
        endedAtMillis: _now().millisecondsSinceEpoch,
        connectedAtMillis: _connectedAt?.millisecondsSinceEpoch,
        failed: phase == TranslationPhase.failed,
      );
      try {
        onFinished?.call(finished!);
      } catch (_) {
        /* Recording must not keep a call alive. */
      }
    }
    if (!mounted) return;
    state = state.copy(
      phase: phase,
      transcripts: _tail.snapshot(_transcripts.items),
      elapsedSeconds: _connectedAt == null
          ? 0
          : translationConnectedSeconds(
              _now().difference(_connectedAt!).inMilliseconds,
            ),
      error: error,
      dtmfFeedbackAvailable: coordinator.supportsDtmf,
    );
    _archive();
    if (!mounted) return;
    if (state.terminal) {
      _timer?.cancel();
    } else if (_timer == null && _connectedAt != null) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted && !state.terminal && !state.stopping) {
          final seconds = translationConnectedSeconds(
            _now().difference(_connectedAt!).inMilliseconds,
          );
          state = state.copy(
            elapsedSeconds: seconds < state.elapsedSeconds
                ? state.elapsedSeconds
                : seconds,
          );
          _archive();
        }
      });
    }
  }

  void _archive({bool terminal = false}) {
    if (onArchive == null || _startedAt == null) return;
    final ended = terminal || _tail.frozen;
    final connected = _connectedAt?.millisecondsSinceEpoch;
    final now = _now().millisecondsSinceEpoch;
    if (ended && connected != null) {
      _archiveEndedAt ??= now > connected ? now : connected + 1;
    }
    final ticket = coordinator.session;
    try {
      onArchive!(
        TranslationArchiveEntry(
          accountId: request.userId,
          clientCallId: context.clientCallId,
          targetName: context.targetName,
          phone: request.phone,
          myLanguage: request.userLanguage,
          peerLanguage: request.merchantLanguage,
          locator: ticket == null
              ? null
              : TranslationArchiveLocator(
                  ticket.clusterId,
                  ticket.id,
                  ticket.recordingAccessGrant,
                ),
          connectedAt: connected,
          lastObservedAt: now,
          endedAt: _archiveEndedAt,
          stage: ended
              ? TranslationArchiveStage.draining
              : TranslationArchiveStage.active,
          transcripts: _tail.snapshot(_transcripts.items),
        ),
      );
    } catch (_) {
      /* Persistence cannot prolong media capture or navigation. */
    }
  }

  bool get _canControl =>
      mounted && !state.terminal && !state.stopping && !state.controlsBusy;
  @override
  Future<void> mute() async {
    if (!_canControl) return;
    final value = !state.muted;
    await _control(
      () => coordinator.setMuted(value),
      () => state.copy(muted: value),
    );
  }

  @override
  Future<void> speaker() async {
    if (!_canControl) return;
    final value = !state.speaker;
    await _control(
      () => coordinator.setSpeaker(value),
      () => state.copy(speaker: value),
    );
  }

  Future<void> _control(
    Future<bool> Function() action,
    TranslationCallView Function() accepted,
  ) async {
    state = state.copy(controlsBusy: true, error: '');
    final success = await action();
    if (!mounted || state.terminal || state.stopping) return;
    state = (success ? accepted() : state.copy(error: '操作未成功，原状态未改变，请重试')).copy(
      controlsBusy: false,
    );
  }

  @override
  void dialPad() {
    if (_canControl) state = state.copy(dialPad: !state.dialPad);
  }

  @override
  Future<void> digit(String digit) async {
    if (!_canControl ||
        !state.dialPad ||
        !RegExp(r'^[0-9*#]$').hasMatch(digit)) {
      return;
    }
    if (!coordinator.supportsDtmf) {
      state = state.copy(error: '当前媒体通道不支持发送按键');
      return;
    }
    if (coordinator.supportsDtmf) {
      try {
        onDtmfInput?.call();
      } catch (_) {
        // Display feedback must never prevent sending an otherwise valid key.
      }
    }
    await _control(() => coordinator.sendDtmf(digit), () {
      final value = '${state.dtmf}$digit';
      return state.copy(
        dtmf: value.length > 16 ? value.substring(value.length - 16) : value,
      );
    });
  }

  @override
  Future<void> hangup() async {
    if (!mounted || state.terminal || state.stopping) return;
    _tail.freeze(_transcripts.items);
    state = state.copy(stopping: true, error: '正在结束通话');
    _timer?.cancel();
    await coordinator.stop();
  }

  @override
  void dispose() {
    _tail.freeze(_transcripts.items, terminal: true);
    _archive(terminal: true);
    _timer?.cancel();
    unawaited(coordinator.dispose().whenComplete(() => onReleased?.call()));
    super.dispose();
  }
}
