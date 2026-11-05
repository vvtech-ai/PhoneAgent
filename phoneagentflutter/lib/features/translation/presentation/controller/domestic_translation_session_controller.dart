import '../../domain/translation_call_failure.dart';
import '../../domain/translation_call_environment.dart';
import '../../domain/domestic_settlement_notice.dart';
import '../../domain/translation_connected_duration.dart';
import '../../domain/translation_transcript_tail.dart';
import '../../../../core/diagnostics/translation_recording_diagnostics.dart';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/recording/domestic_recording_attachment.dart';
import '../../domain/sip/domestic_sip_call_coordinator.dart';
import '../../domain/sip/translation_call_plan.dart';
import '../../domain/translation_archive.dart';
import '../../domain/translation_call_finished.dart';
import '../../domain/translation_call_view.dart';
import 'translation_call_controller.dart';

typedef DomesticCoordinatorBuilder =
    DomesticSipCallCoordinator Function({
      required void Function(TranslationPhase, String) onPhase,
      required void Function(TranslationTranscript) onTranscript,
      required void Function(int) onMediaStopped,
      required void Function(TranslationCallEnvironment) onEnvironment,
    });

/// Domestic presentation uses the same view/controls as the overseas route.
class DomesticTranslationSessionController
    extends StateNotifier<TranslationCallView>
    implements TranslationCallController {
  DomesticTranslationSessionController({
    required this.accountId,
    required this.plan,
    required this.context,
    required this.isCurrent,
    required DomesticCoordinatorBuilder createCoordinator,
    this.onArchive,
    this.onFinished,
    this.onReleased,
    this.onDtmfInput,
    this.finalizeRecording,
    this.recordingDiagnostics = const TranslationRecordingDiagnostics(null),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now,
       super(
         const TranslationCallView(speaker: true, enhancedDtmfFeedback: false),
       ) {
    _tail = TranslationTranscriptTail(_now);
    coordinator = createCoordinator(
      onPhase: _phase,
      onTranscript: _transcript,
      onMediaStopped: _mediaStopped,
      onEnvironment: _environment,
    );
  }
  final String accountId;
  final TranslationCallPlan plan;
  final TranslationCallContext context;
  final bool Function() isCurrent;
  final void Function(TranslationArchiveEntry)? onArchive;
  final void Function(TranslationCallFinished)? onFinished;
  final void Function()? onReleased, onDtmfInput;
  final Future<DomesticRecordingAttachment?> Function(int durationMillis)?
  finalizeRecording;
  final DateTime Function() _now;
  late final DomesticSipCallCoordinator coordinator;
  late final TranslationTranscriptTail _tail;
  final _transcripts = <String, TranslationTranscript>{};
  Timer? _timer;
  int? _started, _connected, _ended;
  bool _recordingPending = false, _terminal = false;
  DomesticRecordingAttachment? _recording;
  TranslationCallFinished? finished;
  final TranslationRecordingDiagnostics recordingDiagnostics;
  String recordingWarning = '';
  bool _environmentUnavailable = false;

  void _environment(TranslationCallEnvironment value) {
    if (!mounted || !isCurrent() || _terminal || state.stopping) return;
    _environmentUnavailable =
        value.overall == TranslationEnvironmentState.unavailable;
    state = state.copy(environment: value);
  }

  @override
  TranslationCallView get snapshot => state;
  @override
  Future<void> start() {
    _started ??= _now().millisecondsSinceEpoch;
    _archive();
    return coordinator.start();
  }

  void _phase(TranslationPhase phase, String code) {
    if (!isCurrent()) return;
    if ((phase == TranslationPhase.connected ||
            phase == TranslationPhase.translating) &&
        _connected == null) {
      _connected = _now().millisecondsSinceEpoch;
      _recordingPending = finalizeRecording != null;
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted && !state.terminal && !state.stopping) {
          state = state.copy(
            elapsedSeconds: translationConnectedSeconds(
              coordinator.billing.durationMs,
            ),
          );
          _archive();
        }
      });
    }
    final terminal =
        phase == TranslationPhase.ended || phase == TranslationPhase.failed;
    if (terminal) {
      _tail.freeze(_transcripts.values, terminal: true);
      _terminal = true;
      _timer?.cancel();
      if (_connected != null) _ended ??= _connected! + 1;
      _archive();
      if (finished == null && _started != null) {
        finished = TranslationCallFinished(
          context: context,
          accountId: accountId,
          phone: plan.target,
          callerLanguage: plan.callerLanguage,
          peerLanguage: plan.peerLanguage,
          startedAtMillis: _started!,
          connectedAtMillis: _connected,
          endedAtMillis: _ended ?? _now().millisecondsSinceEpoch,
          failed: phase == TranslationPhase.failed,
        );
        try {
          onFinished?.call(finished!);
        } catch (_) {
          /* Local metadata only. */
        }
      }
    }
    if (!mounted) return;
    state = state.copy(
      phase: phase,
      transcripts: _tail.snapshot(_transcripts.values),
      elapsedSeconds: terminal && _connected != null
          ? translationConnectedSeconds((_ended ?? _connected!) - _connected!)
          : state.elapsedSeconds,
      stopping: false,
      controlsBusy: false,
      dtmfFeedbackAvailable: phase == TranslationPhase.translating,
      error: code.isEmpty ? recordingWarning : _message(code),
      settlementNotice: terminal
          ? domesticSettlementNotice(coordinator.billing.session)
          : '',
    );
    _archive();
  }

  void _transcript(TranslationTranscript transcript) {
    if (!isCurrent() ||
        _environmentUnavailable ||
        !_tail.accepts(transcript.key)) {
      return;
    }
    _transcripts[transcript.key] = transcript;
    if (mounted) {
      state = state.copy(transcripts: _tail.snapshot(_transcripts.values));
    }
    _archive();
  }

  void _mediaStopped(int durationMillis) {
    final connected = _connected;
    if (connected == null || _ended != null) return;
    final duration = durationMillis > 0 ? durationMillis : 1;
    _ended = connected + duration;
    _tail.freeze(_transcripts.values);
    _timer?.cancel();
    if (mounted) {
      state = state.copy(
        elapsedSeconds: translationConnectedSeconds(duration),
        stopping: true,
        error: '正在结束通话',
      );
    }
    _archive();
    final finalize = finalizeRecording;
    if (finalize != null) unawaited(_finishRecording(finalize, duration));
  }

  Future<void> _finishRecording(
    Future<DomesticRecordingAttachment?> Function(int) finalize,
    int duration,
  ) async {
    try {
      final result = await recordingDiagnostics.run(
        'recordingFinalize',
        () => finalize(duration),
        missingIfNull: true,
      );
      if (result != null && result.durationMillis != duration) {
        throw const FormatException();
      }
      _recording = result;
      if (result == null) recordingWarning = '本次通话录音不可用';
    } catch (_) {
      recordingWarning = '本次通话录音不可用';
    }
    _recordingPending = false;
    _archive(); // Account-owned archive remains live after route disposal.
  }

  void _archive() {
    if (_started == null || !isCurrent()) return;
    try {
      onArchive?.call(
        TranslationArchiveEntry(
          accountId: accountId,
          clientCallId: context.clientCallId,
          targetName: context.targetName,
          phone: plan.target,
          myLanguage: plan.callerLanguage,
          peerLanguage: plan.peerLanguage,
          route: TranslationArchiveRoute.domesticSip,
          recording: _recording,
          recordingPending: _recordingPending,
          connectedAt: _connected,
          lastObservedAt: _now().millisecondsSinceEpoch,
          endedAt: _ended,
          stage: _ended == null && !_terminal
              ? TranslationArchiveStage.active
              : TranslationArchiveStage.draining,
          transcripts: _tail.snapshot(_transcripts.values),
        ),
      );
    } catch (_) {
      /* Persistence cannot keep capture alive. */
    }
  }

  bool get _canControl =>
      mounted &&
      isCurrent() &&
      !state.terminal &&
      !state.stopping &&
      !state.controlsBusy;
  Future<void> _control(
    Future<void> Function() action,
    TranslationCallView Function() accepted,
  ) async {
    if (!_canControl) return;
    state = state.copy(controlsBusy: true, error: '');
    var ok = false;
    try {
      await action();
      ok = true;
    } catch (_) {
      /* Safe presentation error. */
    }
    if (!mounted || state.terminal || state.stopping || !isCurrent()) return;
    state = (ok ? accepted() : state.copy(error: '操作未成功，原状态未改变，请重试')).copy(
      controlsBusy: false,
    );
  }

  @override
  Future<void> mute() async {
    if (!_canControl) return;
    final value = !state.muted;
    await _control(
      () async => coordinator.setMuted(value),
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

  @override
  void dialPad() {
    if (_canControl) state = state.copy(dialPad: !state.dialPad);
  }

  @override
  Future<void> digit(String digit) async {
    if (!_canControl ||
        !state.dialPad ||
        !state.dtmfFeedbackAvailable ||
        !RegExp(r'^[0-9*#]$').hasMatch(digit)) {
      return;
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
    _tail.freeze(_transcripts.values);
    state = state.copy(stopping: true, error: '正在结束通话');
    _timer?.cancel();
    await coordinator.close();
  }

  @override
  void dispose() {
    _tail.freeze(_transcripts.values, terminal: true);
    _timer?.cancel();
    unawaited(coordinator.close().whenComplete(() => onReleased?.call()));
    super.dispose();
  }

  static String _message(String code) => translationCallFailureMessage(code);
}
