import '../../domain/clone_price_policy.dart';
import '../../domain/clone_generation_id.dart';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/clone_candidate.dart';
import '../../domain/clone_creation.dart';
import '../../domain/clone_enrollment.dart';
import '../../domain/clone_verification.dart';
import 'clone_candidate_controller.dart';
import 'clone_candidate_presentation.dart';
import 'clone_completion_controller.dart';
import 'clone_enrollment_controller.dart';
import 'clone_flow_services.dart';
import 'clone_flow_state.dart';
import 'clone_flow_presentation.dart';
import 'clone_flow_snapshot.dart';
import 'clone_verification_controller.dart';

/// Composes the tested protocols; it never retries a write to recover a read.
class CloneFlowController extends StateNotifier<CloneFlowState> {
  CloneFlowController(this.launch, this.services)
    : super(const CloneFlowState());
  final CloneCreationLaunch launch;
  final CloneFlowServices services;
  CloneVerificationController? _verification;
  CloneCandidateController? _candidate;
  CloneCompletionController? _completion;
  CloneFlowSnapshot? _previous;
  VerificationIdentity? _pendingIdentity;
  bool _started = false, _exitPrepared = false;
  bool _working = false;
  int _workId = 0;
  int _previewEpoch = 0;
  bool get _current => mounted && services.isCurrent();
  bool get busy => (_working && !hasCandidateResult) || state.ui.busy;
  bool get exitBlocked =>
      busy || _candidate?.state.candidate?.processing == true;
  bool get hasCandidateResult => exposesCloneCandidate(_candidate?.state);
  bool get candidateReady => _candidate?.state.candidate?.ready == true;
  bool get _restoreOnExit => cloneResultNeedsRestore(state, _completion?.state);
  bool get needsExitConfirmation =>
      _restoreOnExit &&
      _completion?.canSave == true &&
      state.ui.showSaveRecording &&
      state.ui.saveRecording;

  Future<void> start() async {
    if (!_current || _started) return;
    _started = true;
    if (launch.start == CloneCreationStart.existingCandidate) {
      _newCandidate(generated: false);
      await _candidate!.synchronize();
    } else if (launch.start == CloneCreationStart.savedRecording) {
      await _reuse();
    }
  }

  void agree(bool value) {
    if (_current && !busy && state.ui.step == CloneStep.consent) {
      state = state.copy(ui: state.ui.copy(agreed: value));
    }
  }

  Future<void> next() async {
    if (!_current ||
        busy ||
        !state.ui.agreed ||
        state.ui.step != CloneStep.consent) {
      return;
    }
    await _work(() async {
      final loader = services.identityPrefill;
      final prefill = loader != null
          ? await loader()
          : CloneIdentityPrefill(
              name: await services.verifiedName(),
              verified: true,
            );
      if (!_current) return;
      state = presentCloneIdentity(prefill, state);
    }, '身份信息读取失败，请重试');
  }

  Future<void> resetIdentity() async {
    final reset = services.resetIdentity;
    if (!_current ||
        busy ||
        reset == null ||
        state.ui.step != CloneStep.identity ||
        (state.verifiedName.isEmpty && !state.resetCleanupPending)) {
      return;
    }
    await _work(() async {
      final complete = await reset();
      if (!_current) return;
      _previous?.dispose();
      _previous = null;
      _reset('');
      state = CloneFlowState(
        resetCleanupPending: !complete,
        ui: CloneEnrollmentState(
          step: CloneStep.identity,
          agreed: true,
          error: complete ? '' : '身份已删除，本地清理未完成，请重试清理',
        ),
      );
    }, '删除身份失败，请重试');
  }

  void editIdentityNumber() {
    if (_current && !busy && state.verifiedIdCardMasked.isNotEmpty) {
      state = state.copy(verifiedIdCardMasked: '');
    }
  }

  Future<void> submitIdentity(String name, String number) async {
    if (!_current ||
        busy ||
        state.ui.replacement ||
        state.resetCleanupPending ||
        state.ui.step != CloneStep.identity) {
      return;
    }
    if (!services.captureSupported) {
      _error('此平台不支持人脸跟读认证，请在 Android 或 iOS App 中继续');
      return;
    }
    final identity = VerificationIdentity(
      name: state.verifiedName.isEmpty ? name.trim() : state.verifiedName,
      number: number.trim().toUpperCase(),
    );
    if (identity.name.length < 2 || identity.name.length > 32) {
      _error('请输入正确的真实姓名。');
      return;
    }
    if (!validCloneIdentityNumber(identity.number)) {
      _error('请输入正确的身份证号码。');
      return;
    }
    await _work(() async {
      _releaseFailedCreation();
      state = state.copy(creationFailed: false);
      if (!await _admit()) return;
      final replace = await services.verification.replacementRequired(
        identity.number,
      );
      if (!_current) return;
      if (replace) {
        _pendingIdentity = identity;
        state = state.copy(ui: state.ui.copy(replacement: true));
      } else {
        await _verify(identity);
      }
    }, '认证准备未完成，请重试');
  }

  void cancelReplacement() {
    _pendingIdentity = null;
    if (_current) state = state.copy(ui: state.ui.copy(replacement: false));
  }

  Future<void> confirmReplacement() async {
    final identity = _pendingIdentity;
    if (!_current || busy || identity == null) return;
    _pendingIdentity = null;
    state = state.copy(ui: state.ui.copy(replacement: false));
    await _work(
      () => _verify(
        VerificationIdentity(
          name: identity.name,
          number: identity.number,
          replacementConfirmed: true,
        ),
      ),
      '认证未完成，请返回重新认证',
    );
  }

  Future<void> _verify(VerificationIdentity identity) async {
    await stopPreview();
    if (!_current) return;
    _verification?.dispose();
    final verification = CloneVerificationController(
      diagnostics: services.diagnostics,
      repository: services.verification,
      capture: services.capture(),
      isCurrent: () => _current,
    );
    _verification = verification;
    verification.addListener((value) {
      if (!_current || _candidate != null) return;
      state = presentCloneVerification(value, state);
    }, fireImmediately: false);
    await verification.start(identity);
    await _afterVerification();
  }

  Future<void> _afterVerification() async {
    if (!_current || _candidate != null) return;
    final attempt = _verification?.verifiedAttemptId;
    if (attempt == null) return;
    _newCandidate();
    await _candidate!.createFromVerification(attempt, attempt);
    await _handleExpired();
    _releaseFailedCreation();
  }

  void _newCandidate({bool generated = true}) {
    final noticeId = cloneGenerationId();
    final candidate = CloneCandidateController(
      diagnostics: services.diagnostics,
      repository: services.candidates,
      modelId: launch.model.id,
      isCurrent: () => _current,
    );
    _candidate = candidate;
    candidate.addListener((value) {
      if (!_current || !identical(_candidate, candidate)) return;
      final item = value.candidate;
      if (item != null) {
        _previous?.dispose();
        _previous = null;
      }
      if (item != null && !value.creationUncertain) _billing(item);
      final ready = item != null && item.ready;
      final settled = value.phase == CandidatePhase.settled;
      final canUse = settled && ready && !value.creationUncertain;
      if (canUse && _completion == null) _bindCompletion(item);
      state = presentCloneCandidate(
        value,
        current: state,
        hasRecording: _candidate?.recordingGrant != null,
        existingCandidate: launch.start == CloneCreationStart.existingCandidate,
        chargeNoticeId: generated && !value.creationUncertain ? noticeId : null,
      );
    }, fireImmediately: false);
  }

  void _bindCompletion(CloneCandidate candidate) {
    final completion = CloneCompletionController(
      candidate: candidate,
      port: services.completion,
      saveRecording: services.recordings.save,
      prepareRecording: services.recordings.prepareSave,
      isCurrent: () => _current,
      grant: _candidate?.recordingGrant,
    );
    _completion = completion;
    completion.addListener((value) {
      if (!_current || !identical(_completion, completion)) return;
      final confirmed = value.phase == CloneCompletionPhase.confirmed;
      if (confirmed) _billing(candidate, confirmed: true);
      state = presentCloneCompletion(value, state);
    }, fireImmediately: false);
  }

  Future<void> synchronize() async {
    if (!_current || busy || state.recovery == CloneFlowRecovery.none) return;
    await _work(() async {
      switch (state.recovery) {
        case CloneFlowRecovery.verification:
          await _verification?.synchronize();
          await _afterVerification();
        case CloneFlowRecovery.candidate:
          await _candidate?.synchronize();
          await _handleExpired();
        case CloneFlowRecovery.confirmation:
          await _completion?.synchronize();
        case CloneFlowRecovery.none:
        case CloneFlowRecovery.restart:
          break;
      }
    }, '状态尚未同步，请稍后查询');
  }

  Future<void> _reuse() async {
    await _work(() async {
      if (!await _admit()) return;
      final recording = await services.recordings.read();
      if (!_current) return;
      if (recording == null) {
        _reset('认证录音不可用，请重新认证');
        return;
      }
      _newCandidate();
      await _candidate!.createFromRecording(recording, cloneGenerationId());
      await _handleExpired();
      _releaseFailedCreation();
    }, '录音读取或生成未完成，请返回重试');
  }

  void _releaseFailedCreation() {
    if (!_current || !state.creationFailed) return;
    _verification?.dispose();
    _verification = null;
    _candidate?.dispose();
    _candidate = null;
  }

  Future<void> _handleExpired() async {
    if (!_current ||
        _candidate?.state.issue != CandidateIssue.identityExpired) {
      return;
    }
    await services.recordings.clear();
    if (_current) _reset('认证录音或身份已失效，请重新认证');
  }

  Future<bool> _admit() async {
    final error = await refreshedCloneAdmission(
      launch.model,
      models: services.models,
      points: services.points,
      isCurrent: () => _current,
    );
    if (!_current) return false;
    if (error != null) _error(error);
    return error == null;
  }

  Future<void> rerecord() async {
    if (!_current || busy || !state.canRerecord) return;
    final reuse =
        _candidate?.state.candidate?.source ==
        CloneCandidateSource.localRecording;
    await _work(() async {
      if (!await _admit()) return;
      await stopPreview();
      if (!_current) return;
      _previous?.dispose();
      _previous = CloneFlowSnapshot(_candidate!, _completion, state);
      _candidate = null;
      _completion = null;
      _reset('');
      if (reuse) await _reuse();
    }, '重新录制尚未开始，请返回重试');
  }

  bool restorePreviousCandidate({String error = ''}) {
    final previous = _previous;
    if (previous == null || busy) return false;
    _previous = null;
    _reset(error);
    _candidate = previous.candidate;
    _completion = previous.completion;
    state = presentCloneCandidate(
      _candidate!.state,
      current: previous.state,
      hasRecording: _candidate?.recordingGrant != null,
      existingCandidate: false,
    );
    final item = _candidate!.state.candidate;
    if (item?.ready == true && _completion == null) _bindCompletion(item!);
    if (error.isNotEmpty) _error(error);
    return true;
  }

  void restartAuthentication() {
    if (_current && !busy && state.recovery == CloneFlowRecovery.restart) {
      _reset('');
    }
  }

  void _reset(String message) {
    _workId++;
    _working = false;
    _exitPrepared = false;
    _verification?.dispose();
    _verification = null;
    _candidate?.dispose();
    _candidate = null;
    _completion?.dispose();
    _completion = null;
    _pendingIdentity = null;
    state = CloneFlowState(ui: CloneEnrollmentState(error: message));
  }

  void saveRecording(bool value) {
    if (_current &&
        !busy &&
        (_completion?.state.phase == CloneCompletionPhase.ready ||
            _candidate?.recordingGrant != null)) {
      state = state.copy(ui: state.ui.copy(saveRecording: value));
    }
  }

  Future<void> confirm() async {
    if (!_current || busy) return;
    await _work(() async {
      await stopPreview();
      if (_current) await _completion?.confirm(save: state.ui.saveRecording);
    }, '确认未完成，请同步实际状态');
  }

  Future<void> retrySave() async {
    if (!_current || busy) return;
    await _work(() async {
      await _completion?.retrySave();
    }, '录音保存失败');
  }

  Future<void> togglePreview() async {
    if (!_current ||
        busy ||
        state.ui.step != CloneStep.candidate ||
        state.recovery != CloneFlowRecovery.none) {
      return;
    }
    if (state.ui.playing || state.ui.previewLoading) {
      await stopPreview();
      return;
    }
    final epoch = ++_previewEpoch;
    state = state.copy(
      ui: state.ui.copy(playing: false, previewLoading: true, error: ''),
    );
    try {
      final bytes = await services.completion.preview(launch.model.id);
      if (!_current || epoch != _previewEpoch) return;
      state = state.copy(
        ui: state.ui.copy(playing: true, previewLoading: false),
      );
      await services.player.play(bytes);
    } catch (_) {
      if (_current && epoch == _previewEpoch) _error('试听失败，请重试');
    } finally {
      if (_current && epoch == _previewEpoch) {
        state = state.copy(
          ui: state.ui.copy(playing: false, previewLoading: false),
        );
      }
    }
  }

  Future<void> stopPreview() async {
    ++_previewEpoch;
    await services.player.stop();
    if (_current) {
      state = state.copy(
        ui: state.ui.copy(playing: false, previewLoading: false),
      );
    }
  }

  Future<bool> prepareExit() async {
    if (!_current || exitBlocked) return false;
    if (_exitPrepared) return true;
    var allowed = false;
    await _work(() async {
      await stopPreview();
      if (!_current) return;
      if (_restoreOnExit) {
        await services.completion.restoreSystemVoice(launch.model.id);
      }
      allowed = _current;
      if (allowed) _exitPrepared = true;
    }, '系统音色恢复结果未同步，请稍后重试或继续完成');
    return allowed;
  }

  Future<void> _work(Future<void> Function() operation, String failure) async {
    final work = ++_workId;
    _working = true;
    state = state.copy(ui: state.ui.copy(busy: true, error: ''));
    try {
      if (_current) await operation();
    } catch (_) {
      if (_current) _error(failure);
    } finally {
      if (_current && work == _workId) {
        _working = false;
        state = state.copy(ui: state.ui.copy(busy: false));
      }
    }
  }

  void _billing(CloneCandidate candidate, {bool confirmed = false}) {
    if (!_current) return;
    try {
      services.onBilling?.call(candidate, confirmed);
    } catch (_) {
      // A read-only wallet observer cannot undo generation or confirmation.
    }
  }

  void _error(String message) =>
      state = state.copy(ui: state.ui.copy(error: message));

  @override
  void dispose() {
    ++_previewEpoch;
    _pendingIdentity = null;
    _verification?.dispose();
    _candidate?.dispose();
    _completion?.dispose();
    _previous?.dispose();
    unawaited(services.player.close().catchError((Object _) {}));
    super.dispose();
  }
}
