import 'package:phone_agent/features/conversation/domain/history/conversation_history.dart';
import 'package:phone_agent/features/conversation/domain/history/ledger_event.dart';
import 'package:phone_agent/features/feedback/domain/call_evaluation.dart';
import 'package:phone_agent/features/tasks/domain/task_records.dart';

/// Synthetic persisted facts, not simulated call execution or server completion.
abstract final class ShellReceiptSeeds {
  static const singleSession = 'mock-receipt-single';
  static const batchSession = 'mock-receipt-batch';
  static const singleTarget = FeedbackTarget(
    FeedbackTargetKind.call,
    'mock-receipt-call',
  );
  static const batchTarget = FeedbackTarget(
    FeedbackTargetKind.batch,
    'mock-receipt-group',
  );
  static const ids = {singleSession, batchSession};

  static List<TaskRecord> get tasks => [
    for (final id in ids)
      TaskRecord(
        id: 'conversation:$id',
        sessionId: id,
        kind: TaskRecordKind.conversation,
        title: id == singleSession ? 'MOCK · 单路回执与评分' : 'MOCK · 批量回执与赞踩',
        status: TaskStatus.completed,
        rawStatus: 'CLOSED',
        timestamp: '2026-09-20T09:00:00',
      ),
  ];

  static RestoredConversation restore(String sessionId) {
    if (!ids.contains(sessionId)) throw StateError('Unknown MOCK receipt');
    final single = sessionId == singleSession;
    final events = <LedgerEvent>[
      LedgerEvent(
        eventId: '$sessionId:seed-1',
        sessionId: sessionId,
        sequence: 1,
        type: 'USER_TURN_ACCEPTED',
        schemaVersion: 1,
        commandId: 'mock-request',
        payload: {'text': single ? '合成预订需求，未真实拨号' : '合成会议邀请，未真实拨号'},
      ),
      if (single)
        LedgerEvent(
          eventId: '$sessionId:seed-2',
          sessionId: sessionId,
          sequence: 2,
          type: 'CALL_COMPLETED',
          schemaVersion: 1,
          commandId: 'mock-request',
          callId: singleTarget.id,
          callAttemptId: 'mock-attempt',
          payload: {
            'summary': 'MOCK · 合成餐厅回执',
            'callReceipt': {
              'callId': singleTarget.id,
              'targetName': '合成餐厅',
              'callState': 'COMPLETED',
              'dialogueDetail': 'AI：合成预订咨询。\n对方：可以安排两位。',
            },
          },
        )
      else
        LedgerEvent(
          eventId: '$sessionId:seed-2',
          sessionId: sessionId,
          sequence: 2,
          type: 'ASSISTANT_TURN_COMMITTED',
          schemaVersion: 1,
          commandId: 'mock-request',
          payload: {
            'batchCallResult': {
              'batchId': batchTarget.id,
              'status': 'COMPLETED',
              'headline': 'MOCK · 合成会议回执',
              'items': [
                {
                  'itemId': 'one',
                  'targetName': '合成参会者甲',
                  'status': 'SUCCESS',
                  'headline': '确认参加',
                  'callId': 'mock-batch-call-one',
                  'transcript': '对方：确认参加会议。',
                },
                {
                  'itemId': 'two',
                  'targetName': '合成参会者乙',
                  'status': 'FAILED',
                  'headline': '未接通',
                },
              ],
            },
          },
        ),
      if (single)
        LedgerEvent(
          eventId: '$sessionId:seed-3',
          sessionId: sessionId,
          sequence: 3,
          type: 'CALL_OUTCOME_REPORTED',
          schemaVersion: 1,
          commandId: 'mock-request',
          callId: singleTarget.id,
          callAttemptId: 'mock-attempt',
          payload: {'outcome': 'SUCCESS', 'headline': 'MOCK · 已确认两人座位'},
        ),
    ];
    if (single) {
      events.add(
        LedgerEvent(
          eventId: '$sessionId:seed-4',
          sessionId: sessionId,
          sequence: 4,
          type: 'TOOL_RESULT_RECORDED',
          schemaVersion: 1,
          commandId: 'mock-request',
          callId: singleTarget.id,
          callAttemptId: 'mock-attempt',
          payload: {
            'toolName': 'makeCall',
            'toolCallId': 'mock-call-tool',
            'result': {
              'metadata': {'callId': singleTarget.id},
            },
          },
        ),
      );
    }
    return RestoredConversation(
      ConversationDetail(
        sessionId: sessionId,
        title: single ? '单路回执与评分' : '批量回执与赞踩',
        status: 'CLOSED',
      ),
      ledger: LedgerSnapshot(
        sessionId,
        events.length,
        LedgerProjection(
          status: 'CLOSED',
          continuable: false,
          pendingRestorable: false,
          migrationStatus: 'READY',
          projectedThrough: events.length,
        ),
        List.unmodifiable(events),
      ),
    );
  }
}
