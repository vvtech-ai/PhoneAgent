import 'dart:async';
import '../../domain/clone_request_failure.dart';
import '../../../../core/diagnostics/clone_diagnostics.dart';
import '../../../../core/diagnostics/diagnostic_event.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/account_session.dart';
import '../../../call_models/domain/call_models.dart';
import '../../../call_models/domain/clone_voice.dart';
import '../../domain/clone_candidate.dart';

enum CandidatePhase {
  idle,
  submitting,
  synchronizing,
  settled,
  needsSync,
  conflict,
}

enum CandidateIssue {
  none,
  priceChanged,
  requestFailed,
  invalidResponse,
  rejected,
  sessionUnavailable,
  pollLimit,
  identityChanged,
  identityExpired,
}

class CloneCandidateState {
  const CloneCandidateState({
    this.phase = CandidatePhase.idle,
    this.candidate,
    this.issue = CandidateIssue.none,
    this.creationUncertain = false,
    this.failure,
    this.httpStatus = 0,
  });
  final CandidatePhase phase;
  final CloneCandidate? candidate;
  final CandidateIssue issue;
  final CloneGenerationFailure? failure;
  final int httpStatus;
  String get creationError =>
      failure?.message ??
      switch (issue) {
        CandidateIssue.priceChanged => CloneRequestFailure.priceChanged.message,
        CandidateIssue.invalidResponse => '声音克隆返回数据异常，请稍后重新进入。',
        CandidateIssue.sessionUnavailable => '登录状态已变化，请重新登录。',
        CandidateIssue.rejected => '跟读语音处理失败，请重新认证。',
        _ => '声音克隆失败，请重新开始。',
      };

  /// The latest candidate GET has no generationRequestId. Never claim it proves
  /// that an earlier timed-out create succeeded or charged this operation.
  final bool creationUncertain;
  bool get busy =>
      phase == CandidatePhase.submitting ||
      phase == CandidatePhase.synchronizing;
}

/// One controller = one model / opening or generation attempt. Paid admission,
/// SDK verification and account-bound recording storage belong to the caller.
class CloneCandidateController extends StateNotifier<CloneCandidateState> {
  CloneCandidateController({
    required this.repository,
    required String modelId,
    this.diagnostics,
    this.maxPolls = 60,
    this.backgroundInterval = const Duration(seconds: 15),
    this.isCurrent,
    this.interval = const Duration(seconds: 2),
    Future<void> Function(Duration)? delay,
  }) : modelId = normalizeProvider(modelId),
       _delay = delay ?? Future<void>.delayed,
       super(const CloneCandidateState()) {
    if (!supportsCloneVoice(modelId) ||
        maxPolls < 1 ||
        interval.isNegative ||
        backgroundInterval <= Duration.zero) {
      throw ArgumentError('Invalid candidate observation configuration');
    }
  }
  final CloneDiagnostics? diagnostics;
  final CloneCandidateRepository repository;
  final String modelId;
  final int maxPolls;
  final Duration interval, backgroundInterval;
  final bool Function()? isCurrent;
  Timer? _background;
  final Future<void> Function(Duration) _delay;
  bool _started = false;
  int _generation = 0;
  String? _candidateId;
  CloneRecordingGrant? _recording;
  CloneRecordingGrant? get recordingGrant => mounted ? _recording : null;

  Future<void> createFromVerification(String attemptId, String requestId) =>
      _create(() => repository.fromVerification(modelId, attemptId, requestId));
  Future<void> createFromRecording(
    CertifiedCloneRecording recording,
    String requestId,
  ) => _create(() => repository.fromRecording(modelId, recording, requestId));

  Future<void> _create(
    Future<CloneGeneratedCandidate> Function() submit,
  ) async {
    if (!mounted || !(isCurrent?.call() ?? true) || _started) return;
    _started = true;
    _background?.cancel();
    final generation = ++_generation;
    state = const CloneCandidateState(phase: CandidatePhase.submitting);
    try {
      final result = await submit();
      if (!_current(generation)) return;
      _recording = result.recording;
      if (!_accept(result.candidate)) return;
      await _poll(generation);
    } on CloneGenerationException catch (error) {
      if (_current(generation)) {
        _set(
          CandidatePhase.needsSync,
          issue: CandidateIssue.requestFailed,
          failure: error.failure,
          httpStatus: error.httpStatus,
          uncertain:
              error.failure == CloneGenerationFailure.submissionUnknown &&
              state.candidate == null,
        );
      }
    } on CloneGenerationFailure catch (failure) {
      if (_current(generation)) {
        _set(
          CandidatePhase.needsSync,
          issue: failure == CloneGenerationFailure.identityExpired
              ? CandidateIssue.identityExpired
              : CandidateIssue.requestFailed,
          failure: failure,
          uncertain:
              failure == CloneGenerationFailure.submissionUnknown &&
              state.candidate == null,
        );
      }
    } catch (error) {
      if (_current(generation)) {
        _set(
          CandidatePhase.needsSync,
          issue: switch (error) {
            CloneRequestFailure.priceChanged => CandidateIssue.priceChanged,
            ApiFailure.invalidResponse => CandidateIssue.invalidResponse,
            ApiFailure.rejected || ApiHttpFailure() => CandidateIssue.rejected,
            ApiFailure.signedOut ||
            ApiFailure.sessionChanged => CandidateIssue.sessionUnavailable,
            _ => CandidateIssue.requestFailed,
          },
          uncertain:
              error != CloneRequestFailure.priceChanged &&
              state.candidate == null,
          httpStatus: error is ApiHttpFailure ? error.statusCode : 0,
        );
      }
    } finally {
      _observeLater(generation);
    }
  }

  /// Explicit retry means GET only. It cannot create, confirm, delete or charge.
  Future<void> synchronize() async {
    if (!mounted ||
        !(isCurrent?.call() ?? true) ||
        state.busy ||
        state.phase == CandidatePhase.conflict ||
        state.issue == CandidateIssue.identityExpired) {
      return;
    }
    _started = true;
    _background?.cancel();
    final generation = ++_generation;
    _set(CandidatePhase.synchronizing);
    try {
      final candidate = await repository.read(modelId);
      if (!_current(generation) || !_accept(candidate)) return;
      await _poll(generation);
    } catch (_) {
      if (_current(generation)) {
        _set(CandidatePhase.needsSync, issue: CandidateIssue.requestFailed);
        _observeLater(generation);
      }
    }
  }

  bool _accept(CloneCandidate candidate) {
    if (candidate.modelId != modelId ||
        (_candidateId?.isNotEmpty == true &&
            candidate.id.isNotEmpty &&
            candidate.id != _candidateId)) {
      _recording = null;
      _set(CandidatePhase.conflict, issue: CandidateIssue.identityChanged);
      return false;
    }
    if (candidate.id.isNotEmpty) _candidateId = candidate.id;
    state = CloneCandidateState(
      phase: candidate.processing
          ? CandidatePhase.synchronizing
          : CandidatePhase.settled,
      candidate: candidate,
      creationUncertain: state.creationUncertain,
    );
    return true;
  }

  Future<void> _poll(int generation) async {
    for (
      var count = 0;
      count < maxPolls && _current(generation) && state.candidate!.processing;
      count++
    ) {
      diagnostics?.event(
        DiagnosticCloneStage.candidateRead,
        DiagnosticResult.started,
        pollCount: count + 1,
      );
      await _delay(interval);
      if (!_current(generation)) return;
      final candidate = await repository.read(modelId);
      if (!_current(generation) || !_accept(candidate)) return;
    }
    if (_current(generation) && state.candidate!.processing) {
      _set(CandidatePhase.needsSync, issue: CandidateIssue.pollLimit);
      _observeLater(generation);
    }
  }

  void _observeLater(int generation) {
    _background?.cancel();
    if (!_current(generation) || state.candidate?.processing != true) return;
    _background = Timer(backgroundInterval, () async {
      if (!_current(generation)) return;
      try {
        final candidate = await repository.read(modelId);
        if (!_current(generation) || !_accept(candidate)) return;
        if (candidate.processing) {
          _set(CandidatePhase.needsSync, issue: CandidateIssue.pollLimit);
        }
      } catch (_) {
        if (_current(generation)) {
          _set(CandidatePhase.needsSync, issue: CandidateIssue.requestFailed);
        }
      }
      _observeLater(generation);
    });
  }

  void _set(
    CandidatePhase phase, {
    CandidateIssue issue = CandidateIssue.none,
    bool? uncertain,
    CloneGenerationFailure? failure,
    int httpStatus = 0,
  }) {
    diagnostics?.event(
      DiagnosticCloneStage.candidateState,
      DiagnosticResult.received,
      state: phase.name,
      issue: issue.name,
    );
    state = CloneCandidateState(
      phase: phase,
      candidate: state.candidate,
      issue: issue,
      failure: failure ?? state.failure,
      httpStatus: httpStatus == 0 ? state.httpStatus : httpStatus,
      creationUncertain: uncertain ?? state.creationUncertain,
    );
  }

  bool _current(int generation) =>
      mounted && generation == _generation && (isCurrent?.call() ?? true);
  @override
  void dispose() {
    ++_generation;
    _background?.cancel();
    _recording = null;
    super.dispose();
  }
}
