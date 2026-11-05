import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/conversation_messages.dart';
import 'package:phone_agent/features/conversation/domain/conversation_message_merge.dart';
import 'package:phone_agent/features/conversation/domain/receipts/call_receipt.dart';
import 'package:phone_agent/features/conversation/domain/history/ledger_event.dart';

LedgerEvent fact(
  int sequence,
  String type, {
  String? attempt,
  Map<String, Object?> payload = const {},
}) => LedgerEvent(
  eventId: 'e$sequence',
  sessionId: 's',
  sequence: sequence,
  schemaVersion: 1,
  commandId: 'c',
  type: type,
  callAttemptId: attempt,
  payload: payload,
);
void main() {
  test('a shared call ID cannot collapse distinct explicit attempts', () {
    ConversationMessage message(String id, String attempt) =>
        ConversationMessage(
          id: id,
          role: MessageRole.assistant,
          text: '',
          receipt: CallReceipt(
            attemptId: attempt,
            callId: 'same-call',
            status: 'FAILED',
          ),
        );
    expect(
      ConversationMessageMerge.merge(
        [message('durable', 'first')],
        [message('retry', 'second')],
      ).map((e) => e.id),
      ['durable', 'retry'],
    );
    expect(
      ConversationMessageMerge.merge(
        [message('durable', 'first')],
        [message('legacy-live', '')],
      ).map((e) => e.id),
      ['durable'],
    );
  });
  test(
    'receipt position follows first call fact, final enrichment does not reorder chat',
    () {
      final messages = ConversationMessages.project([
        fact(1, 'USER_TURN_ACCEPTED', payload: {'text': '合成请求'}),
        fact(2, 'CALL_REQUESTED', attempt: 'a'),
        fact(3, 'ASSISTANT_TURN_COMMITTED', payload: {'text': '执行摘要'}),
        fact(4, 'CALL_COMPLETED', attempt: 'a', payload: {'summary': '已结束'}),
        fact(5, 'CALL_REQUESTED', attempt: 'retry'),
        fact(6, 'CALL_FAILED', attempt: 'retry'),
      ]);
      expect(messages.map((m) => m.id), [
        'ledger:e1',
        'ledger:call:a',
        'ledger:e3',
        'ledger:call:retry',
      ]);
      expect(messages[1].receipt!.headline, '已结束');
      expect(messages[2].text, '执行摘要');
    },
  );
  test(
    'durable receipt replaces live identity, not sibling attempts or ordinary text',
    () {
      ConversationMessage receipt(String id, String attempt) =>
          ConversationMessage(
            id: id,
            role: MessageRole.assistant,
            text: '',
            commandId: 'c',
            receipt: CallReceipt(attemptId: attempt, status: 'COMPLETED'),
          );
      const text = ConversationMessage(
        id: 'text',
        role: MessageRole.assistant,
        text: '总结',
        commandId: 'c',
      );
      final result = ConversationMessageMerge.merge(
        [receipt('durable', 'a')],
        [receipt('live', 'a'), receipt('sibling', 'b'), text],
      );
      expect(result.map((m) => m.id), ['durable', 'sibling', 'text']);
    },
  );
}
