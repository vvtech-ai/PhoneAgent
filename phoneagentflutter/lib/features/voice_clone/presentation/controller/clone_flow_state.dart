import 'clone_enrollment_controller.dart';

enum CloneFlowRecovery { none, verification, candidate, confirmation, restart }

class CloneFlowState {
  const CloneFlowState({
    this.ui = const CloneEnrollmentState(),
    this.recovery = CloneFlowRecovery.none,
    this.verifiedName = '',
    this.chargeNotice = '',
    this.chargeNoticeId = '',
    this.prefilledName = '',
    this.verifiedIdCardMasked = '',
    this.resetCleanupPending = false,
    this.creationModelError = '',
    this.saveFailed = false,
    this.canRerecord = false,
    this.creationFailed = false,
    this.identityRetry = false,
  });
  final CloneEnrollmentState ui;
  final CloneFlowRecovery recovery;
  final String chargeNotice, chargeNoticeId;
  final String verifiedName,
      prefilledName,
      creationModelError,
      verifiedIdCardMasked;
  final bool resetCleanupPending;
  final bool saveFailed, canRerecord, creationFailed;
  final bool identityRetry;
  CloneFlowState copy({
    CloneEnrollmentState? ui,
    CloneFlowRecovery? recovery,
    String? verifiedName,
    String? chargeNotice,
    String? chargeNoticeId,
    String? prefilledName,
    String? verifiedIdCardMasked,
    bool? resetCleanupPending,
    String? creationModelError,
    bool? saveFailed,
    bool? canRerecord,
    bool? creationFailed,
    bool? identityRetry,
  }) => CloneFlowState(
    ui: ui ?? this.ui,
    recovery: recovery ?? this.recovery,
    verifiedName: verifiedName ?? this.verifiedName,
    chargeNotice: chargeNotice ?? this.chargeNotice,
    chargeNoticeId: chargeNoticeId ?? this.chargeNoticeId,
    prefilledName: prefilledName ?? this.prefilledName,
    verifiedIdCardMasked: verifiedIdCardMasked ?? this.verifiedIdCardMasked,
    resetCleanupPending: resetCleanupPending ?? this.resetCleanupPending,
    creationModelError: creationModelError ?? this.creationModelError,
    saveFailed: saveFailed ?? this.saveFailed,
    canRerecord: canRerecord ?? this.canRerecord,
    creationFailed: creationFailed ?? this.creationFailed,
    identityRetry: identityRetry ?? this.identityRetry,
  );
}
