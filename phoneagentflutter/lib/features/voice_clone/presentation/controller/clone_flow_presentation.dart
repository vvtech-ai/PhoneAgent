import '../../domain/clone_enrollment.dart';
import 'clone_verification_controller.dart';
import 'clone_completion_controller.dart';
import 'clone_flow_state.dart';
import 'clone_flow_services.dart';

bool cloneResultNeedsRestore(
  CloneFlowState flow,
  CloneCompletionState? completion,
) =>
    flow.ui.step == CloneStep.candidate &&
    completion?.phase == CloneCompletionPhase.ready;

/// Pure protocol-to-view projection, independent of service ownership.
CloneFlowState presentCloneVerification(
  CloneVerificationState value,
  CloneFlowState state,
) {
  final failed = const {
    VerificationPhase.failed,
    VerificationPhase.rejected,
    VerificationPhase.cancelled,
  }.contains(value.phase);
  final onIdentity =
      const {
        VerificationPhase.idle,
        VerificationPhase.preparing,
        VerificationPhase.initializing,
      }.contains(value.phase) ||
      failed;
  final recovery = onIdentity
      ? CloneFlowRecovery.none
      : value.phase == VerificationPhase.needsSync
      ? CloneFlowRecovery.verification
      : value.busy || value.phase == VerificationPhase.passed
      ? CloneFlowRecovery.none
      : CloneFlowRecovery.restart;
  return state.copy(
    identityRetry: failed,
    recovery: recovery,
    ui: state.ui.copy(
      step: onIdentity
          ? CloneStep.identity
          : value.phase == VerificationPhase.checking
          ? CloneStep.checking
          : CloneStep.collecting,
      busy: value.busy,
      script: failed ? '' : value.script,
      error: onIdentity && failed
          ? value.failureMessage
          : recovery == CloneFlowRecovery.none
          ? ''
          : recovery == CloneFlowRecovery.verification
          ? '认证结果待同步，请查询本次结果，不会重新发起认证'
          : value.failureMessage,
    ),
  );
}

CloneFlowState presentCloneCompletion(
  CloneCompletionState value,
  CloneFlowState state,
) {
  final confirmed = value.phase == CloneCompletionPhase.confirmed;
  return state.copy(
    saveFailed: value.recording == CloneRecordingSave.failed,
    canRerecord: false,
    recovery: value.phase == CloneCompletionPhase.needsSync
        ? CloneFlowRecovery.confirmation
        : CloneFlowRecovery.none,
    ui: state.ui.copy(
      step: confirmed ? CloneStep.confirmed : CloneStep.candidate,
      busy: value.busy,
      playing: false,
      error: value.phase == CloneCompletionPhase.needsSync
          ? '音色状态尚未同步，请稍后重试'
          : value.recording == CloneRecordingSave.failed
          ? '声音已设为默认，但认证录音保存失败；可单独重试保存'
          : '',
    ),
  );
}

CloneFlowState presentCloneIdentity(
  CloneIdentityPrefill prefill,
  CloneFlowState state,
) {
  final name = prefill.name.trim();
  final masked = prefill.certNoMasked.trim();
  return state.copy(
    verifiedName: prefill.verified ? name : '',
    prefilledName: name,
    // Never display an unexpectedly unmasked full certificate number.
    verifiedIdCardMasked: prefill.verified && masked.contains('*')
        ? masked
        : '',
    ui: state.ui.copy(step: CloneStep.identity, error: ''),
  );
}
