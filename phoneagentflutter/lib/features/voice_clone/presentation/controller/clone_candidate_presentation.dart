import '../../domain/clone_enrollment.dart';
import '../../domain/clone_candidate.dart';
import 'clone_candidate_controller.dart';
import 'clone_flow_state.dart';

bool exposesCloneCandidate(CloneCandidateState? value) =>
    value?.creationUncertain == false &&
    value?.candidate != null &&
    value?.candidate?.status != CloneCandidateStatus.failed;

/// Native candidate surface mapping, independent of API and route ownership.
CloneFlowState presentCloneCandidate(
  CloneCandidateState value, {
  required CloneFlowState current,
  required bool hasRecording,
  required bool existingCandidate,
  String? chargeNoticeId,
}) {
  final item = value.candidate;
  final ready = exposesCloneCandidate(value) && item!.ready;
  final canUse =
      value.phase == CandidatePhase.settled &&
      ready &&
      !value.creationUncertain;
  final creationFailed =
      item?.status == CloneCandidateStatus.failed && !value.creationUncertain ||
      item == null &&
          value.phase == CandidatePhase.needsSync &&
          !value.creationUncertain &&
          value.issue != CandidateIssue.identityExpired;
  final charged =
      chargeNoticeId != null &&
      ready &&
      item.chargedPoints > 0 &&
      item.remainingPoints != null;
  return current.copy(
    chargeNoticeId: charged ? chargeNoticeId : null,
    chargeNotice: charged
        ? '本次扣除 ✦${item.chargedPoints} 积分，剩余 ✦${item.remainingPoints} 积分'
        : null,
    creationFailed: creationFailed,
    creationModelError: !creationFailed
        ? ''
        : value.httpStatus >= 500 ||
              value.failure == CloneGenerationFailure.cloneProvider
        ? '声音克隆服务暂时不可用，请稍后重试。'
        : value.failure != null
        ? '声音克隆完成失败'
        : value.creationError,
    recovery:
        !creationFailed &&
            (value.phase == CandidatePhase.needsSync ||
                value.creationUncertain) &&
            value.issue != CandidateIssue.identityExpired
        ? CloneFlowRecovery.candidate
        : CloneFlowRecovery.none,
    canRerecord:
        !creationFailed &&
        !value.creationUncertain &&
        item != null &&
        !item.processing,
    ui: current.ui.copy(
      step: creationFailed
          ? CloneStep.identity
          : canUse
          ? CloneStep.candidate
          : item?.processing == true || value.busy || value.creationUncertain
          ? CloneStep.generating
          : CloneStep.candidateError,
      busy: value.busy && item == null,
      playing: false,
      showSaveRecording: hasRecording,
      error: creationFailed
          ? item?.failureMessage.isNotEmpty == true
                ? item!.failureMessage
                : existingCandidate
                ? '声音生成状态暂不可用，请稍后重试'
                : value.creationError
          : value.phase == CandidatePhase.conflict
          ? '候选已被其他操作替换，请返回刷新'
          : value.creationUncertain
          ? '声音克隆结果待同步，请查询本次结果，勿重复认证'
          : item?.processing == true
          ? value.phase == CandidatePhase.needsSync
                ? '声音仍在生成，完成后将自动更新'
                : ''
          : item?.failureMessage.isNotEmpty == true
          ? item!.failureMessage
          : !canUse && !value.busy
          ? '声音生成状态暂不可用，请稍后重试'
          : '',
    ),
  );
}
