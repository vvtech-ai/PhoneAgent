import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/conversation_messages.dart';
import 'package:phone_agent/features/conversation/domain/conversation_message_merge.dart';
import 'package:phone_agent/features/conversation/domain/receipts/call_receipt.dart';

ConversationMessage receipt(String id, Map<String, Object?> data) =>
    ConversationMessage(
      id: id,
      role: MessageRole.assistant,
      text: id,
      commandId: id,
      receipt: CallReceipt.fromResult(data),
    );

Map<String, Object?> liveResult(String attempt) => {
  'status': 'COMPLETED',
  'callAttemptId': attempt,
  'callId': 'server-call',
  'metadata': {
    'callId': 'server-call',
    'sceneType': 'restaurant_booking',
    'dialogueDetail': 'assistant: 测试转写',
  },
  'receiptFields': [
    {'key': 'restaurant', 'label': '餐厅', 'value': '测试餐厅'},
  ],
  'billingSummary': {
    'billingSessionId': 'usage',
    'billingState': 'SETTLED',
    'chargedPoints': 0,
    'remainingPoints': 12,
  },
};

void main() {
  test('ledger terminal retains same-attempt live media and zero billing', () {
    final fact = receipt('durable', {
      'status': 'FAILED',
      'callAttemptId': 'attempt',
      'detail': '持久结果',
      'metadata': {'sceneType': 'durable-scene'},
    });
    final live = receipt('live', liveResult('attempt'));
    final merged = ConversationMessageMerge.merge([fact], [live]);
    expect(merged, hasLength(1));
    expect(merged.single.id, 'durable');
    expect(merged.single.text, 'durable');
    final result = merged.single.receipt!;
    expect(result.status, 'FAILED');
    expect(result.detail, '持久结果');
    expect(result.callId, 'server-call');
    expect(result.recordingCallId, 'server-call');
    expect(result.fields.single.value, '测试餐厅');
    expect(result.billing?.chargedPoints, 0);
    expect(result.metadata['sceneType'], 'durable-scene');
    expect(fact.receipt!.callId, isEmpty);
    expect(fact.receipt!.billing, isNull);
  });
  test('durable fields and billing win; separate attempts never borrow', () {
    final fact = receipt('durable', {
      ...liveResult('attempt'),
      'billingSummary': {
        'billingSessionId': 'canonical-usage',
        'chargedPoints': 7,
      },
    });
    final result = ConversationMessageMerge.merge(
      [fact],
      [receipt('live', liveResult('attempt'))],
    ).single.receipt!;
    expect(result.billing?.sessionId, 'canonical-usage');
    expect(result.billing?.chargedPoints, 7);
    final other = receipt('other', {
      'status': 'FAILED',
      'callAttemptId': 'different-attempt',
    });
    final isolated = ConversationMessageMerge.merge(
      [other],
      [receipt('live', liveResult('attempt'))],
    );
    expect(isolated, hasLength(2));
    expect(isolated.first.receipt!.recordingCallId, isNull);
    expect(isolated.first.receipt!.billing, isNull);
  });
  test('same-call transcript survives an empty ledger terminal', () {
    final fact = receipt('durable', {
      'status': 'COMPLETED',
      'callAttemptId': 'attempt',
    });
    final merged = ConversationMessageMerge.merge(
      [fact],
      [receipt('live', liveResult('attempt'))],
    );
    expect(merged.single.receipt!.transcript, 'assistant: 测试转写');
    expect(fact.receipt!.transcript, isEmpty);
  });
}
