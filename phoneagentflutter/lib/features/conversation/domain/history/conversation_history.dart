import 'ledger_event.dart';

class ConversationDetail {
  const ConversationDetail({
    required this.sessionId,
    required this.title,
    required this.status,
    this.sceneType = '',
    this.createdAt = '',
    this.updatedAt = '',
    this.activeBatchId = '',
    this.activeCommandId = '',
    this.pinnedSkillId = '',
    this.taskCallModelId = '',
  });
  final String sessionId, title, status, sceneType, createdAt, updatedAt;
  final String activeBatchId, activeCommandId;
  final String pinnedSkillId, taskCallModelId;
}

class RestoredConversation {
  const RestoredConversation(
    this.detail, {
    this.ledger,
    this.compatibilityReason,
  });
  final ConversationDetail detail;
  final LedgerSnapshot? ledger;
  final TimelineFailure? compatibilityReason;
  // Deliberately not an input gate. v65 keeps the unified input available.
  bool get canRestorePending =>
      ledger != null &&
      ledger!.projection.status.toUpperCase() != 'CLOSED' &&
      ledger!.projection.continuable &&
      ledger!.projection.pendingRestorable;

  LedgerEvent? get pendingTool {
    if (!canRestorePending) return null;
    String identity(LedgerEvent e) => [
      'modelTurnId',
      'toolCallId',
      'toolName',
      'ordinal',
    ].map((k) => e.payload[k]?.toString() ?? '').join(':');
    final resolved = ledger!.events
        .where((e) => e.type == 'TOOL_RESULT_RECORDED')
        .map(identity)
        .toSet();
    for (final event in ledger!.events.reversed) {
      if (event.type == 'TOOL_REQUESTED' &&
          !resolved.contains(identity(event))) {
        return event;
      }
    }
    return null;
  }
}

abstract interface class ConversationHistoryRepository {
  Future<RestoredConversation> restore(String sessionId);
}
