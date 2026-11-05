class CallSessionTarget {
  CallSessionTarget({
    String taskId = '',
    String callId = '',
    String attemptId = '',
  }) : taskId = taskId.trim(),
       callId = callId.trim(),
       attemptId = attemptId.trim();
  final String taskId, callId, attemptId;
  bool get isValid => taskId.isNotEmpty || callId.isNotEmpty;

  CallSessionTarget resolve(CallSessionSnapshot snapshot) => CallSessionTarget(
    taskId: taskId.isEmpty ? snapshot.taskId : taskId,
    callId: callId.isEmpty ? snapshot.callId : callId,
    attemptId: attemptId,
  );
}

/// A transport snapshot, never evidence that the Agent's business goal succeeded.
class CallSessionSnapshot {
  const CallSessionSnapshot({
    required this.callId,
    required this.taskId,
    required this.callState,
    this.handoffMode = '',
    this.sceneType = '',
    this.targetName = '',
    this.phoneNumber = '',
    this.backendCallEnabled = false,
    this.handoffSupported = false,
    this.appRtcRequired = false,
    this.dialogueDetail = '',
    this.statusMessage = '',
    this.resultCode = '',
    this.resultReason = '',
    this.resultText = '',
    this.updatedAt = '',
    this.launchReady = false,
    this.dialFailureObserved = false,
    this.primaryClosed = false,
  });
  final String callId, taskId, callState, handoffMode, sceneType;
  final String targetName, phoneNumber, dialogueDetail, statusMessage;
  final String resultCode, resultReason, resultText, updatedAt;
  final bool backendCallEnabled, handoffSupported, appRtcRequired;
  final bool launchReady;
  final bool dialFailureObserved, primaryClosed;
  String get normalizedState => callState.trim().toUpperCase();
  bool get isNotFound => normalizedState == 'NOT_FOUND';
  bool get isTerminal =>
      const {'ENDED', 'FAILED', 'NOT_FOUND'}.contains(normalizedState);
  DateTime? get timestamp => DateTime.tryParse(updatedAt.trim());

  bool belongsTo(CallSessionTarget target) {
    if (!target.isValid || callState.trim().isEmpty) return false;
    if (target.taskId.isNotEmpty && target.taskId != taskId) return false;
    if (target.callId.isNotEmpty && target.callId != callId) {
      return isNotFound && callId.isEmpty;
    }
    return callId.isNotEmpty || isNotFound;
  }

  bool needsAgentOutcome(
    String conversationId, {
    bool hasAgentOutcome = false,
  }) {
    if (hasAgentOutcome || taskId.isEmpty || taskId != conversationId.trim()) {
      return false;
    }
    final mode = handoffMode.trim().toUpperCase();
    final transportFinished =
        (normalizedState == 'ENDED' && mode == 'COMPLETED') ||
        (normalizedState == 'FAILED' && mode == 'FAILED');
    return transportFinished &&
        !resultCode.trim().toUpperCase().startsWith('AGENT_');
  }
}

/// Kept at the media boundary, not in visible UI state or diagnostic strings.
class CallMonitorTicket {
  const CallMonitorTicket({
    required this.ticket,
    required this.expiresAt,
    required this.sampleRate,
    required this.channels,
    required this.encoding,
  });
  final String ticket, encoding;
  final DateTime expiresAt;
  final int sampleRate, channels;
  @override
  String toString() => 'CallMonitorTicket(redacted)';
}

abstract interface class CallSessionRepository {
  Future<CallSessionSnapshot> status(CallSessionTarget target);
  Future<CallSessionSnapshot> hangUp(CallSessionTarget target);
  Future<CallMonitorTicket> monitorTicket(CallSessionTarget target);
}
