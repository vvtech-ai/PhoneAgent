import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/conversation_messages.dart';
import 'package:phone_agent/features/conversation/domain/conversation_live_messages.dart';
import 'package:phone_agent/features/conversation/domain/conversation_message_merge.dart';
import 'package:phone_agent/features/conversation/domain/history/ledger_event.dart';
import 'package:phone_agent/features/conversation/domain/receipts/call_receipt.dart';
import 'package:phone_agent/features/conversation/domain/receipts/call_receipt_projector.dart';
import 'package:phone_agent/features/conversation/domain/receipts/receipt_message_mapper.dart';

LedgerEvent fact(
  int seq,
  String type, {
  String command = 'c',
  Map<String, Object?> payload = const {},
}) => LedgerEvent(
  eventId: 'e$seq',
  sessionId: 's',
  sequence: seq,
  schemaVersion: 1,
  commandId: command,
  callAttemptId: 'attempt',
  type: type,
  payload: payload,
);

void main() {
  test('nonterminal live result payload cannot create post-call assets', () {
    expect(
      ReceiptMessageMapper.fromFinal({
        'callResult': {
          'status': 'CALL_STARTED',
          'metadata': {'callId': 'call'},
        },
      }, 'c'),
      isEmpty,
    );
  });
  test(
    'confirmed batch retains one card without identical standalone prompt',
    () {
      const prompt = '请确认以上任务理解，确认后我再开始执行。';
      final messages = ConversationMessages.project([
        fact(
          1,
          'TOOL_REQUESTED',
          payload: {
            'toolName': 'confirmBatchTask',
            'toolCallId': 'batch-confirm',
            'displayPayloadVersion': 1,
            'arguments': {
              'snapshotJson': {'title': '合成任务', 'sections': []},
            },
          },
        ),
        fact(
          2,
          'TOOL_RESULT_RECORDED',
          payload: {
            'toolName': 'confirmBatchTask',
            'toolCallId': 'batch-confirm',
            'result': {'decision': 'CONFIRMED'},
          },
        ),
        fact(3, 'ASSISTANT_TURN_COMMITTED', payload: {'text': prompt}),
        fact(4, 'ASSISTANT_TURN_COMMITTED', payload: {'text': '独立回复'}),
      ]);
      expect(messages.where((m) => m.batchConfirmation != null), hasLength(1));
      expect(
        messages.where((m) => m.batchConfirmation == null && m.text == prompt),
        isEmpty,
      );
      expect(messages.any((m) => m.text == '独立回复'), isTrue);
    },
  );
  test(
    'running ledger remains observable without result assets in messages',
    () {
      final facts = [fact(1, 'CALL_REQUESTED'), fact(2, 'CALL_STARTED')];
      expect(
        CallReceiptProjector.project(facts).single.receipt.isRunning,
        isTrue,
      );
      expect(
        ConversationMessages.project(facts).where((m) => m.receipt != null),
        isEmpty,
      );
      final finished = ConversationMessages.project([
        ...facts,
        fact(3, 'CALL_COMPLETED'),
      ]);
      expect(finished.single.receipt!.attemptId, 'attempt');
    },
  );
  test('same pending card reconciles across command boundaries', () {
    const spec = {'targetName': '合成目标', 'phoneNumber': '10086'};
    final durable = ConversationMessages.project([
      fact(
        1,
        'TOOL_REQUESTED',
        payload: {
          'toolName': 'makeCall',
          'toolCallId': 'pending',
          'arguments': spec,
        },
      ),
    ]);
    final live = ConversationLiveMessages.confirmation(
      'later',
      'pending',
      spec,
    )!;
    final merged = ConversationMessageMerge.merge(durable, [live]);
    expect(merged.where((m) => m.confirmation != null), hasLength(1));
    expect(merged.map((m) => m.id), [
      'ledger:call-confirmation:pending',
      'ledger:call-confirmation:pending:prompt',
    ]);
    expect(merged.last.text, '请确认以上任务内容，是否现在拨打？');
    final next = ConversationLiveMessages.confirmation(
      'later',
      'new-pending',
      spec,
    )!;
    final nextTurn = ConversationMessageMerge.merge(durable, [next]);
    expect(nextTurn.where((m) => m.confirmation != null), hasLength(2));
    expect(nextTurn.where((m) => m.text == '请确认以上任务内容，是否现在拨打？'), hasLength(1));
  });
  test('legacy call alias dedupes only with matching call ID evidence', () {
    ConversationMessage message(String id, String attempt, String call) =>
        ConversationMessage(
          id: id,
          role: MessageRole.assistant,
          text: '',
          receipt: CallReceipt(
            attemptId: attempt,
            callId: call,
            status: 'FAILED',
          ),
        );
    final durable = message('durable', 'call-1', 'call-1');
    expect(
      ConversationMessageMerge.merge(
        [durable],
        [message('live', 'call:call-1', 'call-1')],
      ).length,
      1,
    );
    expect(
      ConversationMessageMerge.merge(
        [durable],
        [message('other', 'call:call-1', 'other')],
      ).length,
      2,
    );
  });
}
