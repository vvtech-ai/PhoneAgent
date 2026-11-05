import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/agent_protocol.dart';
import 'package:phone_agent/features/conversation/domain/conversation_messages.dart';
import 'package:phone_agent/features/conversation/domain/history/ledger_event.dart';
import 'package:phone_agent/features/conversation/domain/voice/committed_reply_narration.dart';

LedgerEvent reply({
  String id = 'reply',
  int sequence = 2,
  String reason = 'call_result',
  String session = 's',
  String text = '持久结果。',
}) => LedgerEvent(
  eventId: id,
  sessionId: session,
  sequence: sequence,
  type: 'ASSISTANT_TURN_COMMITTED',
  schemaVersion: 1,
  payload: {'text': text, 'finishReason': reason},
);
LedgerEvent receipt({String call = 'call', int sequence = 1}) => LedgerEvent(
  eventId: 'receipt-$call',
  sessionId: 's',
  sequence: sequence,
  type: 'CALL_COMPLETED',
  schemaVersion: 1,
  payload: const {},
  callId: call,
  callAttemptId: 'attempt-$call',
);
AgentEvent terminal({
  String call = 'call',
  bool batch = false,
  String session = 's',
}) => AgentEvent(
  AgentEventKind.finalResponse,
  sessionId: session,
  text: '不播瞬态正文',
  payload: batch
      ? {
          'type': 'BATCH_CALL_RESULT',
          'batchCallResult': {'batchId': call},
        }
      : {
          'type': 'CALL_RESULT',
          'callResult': {
            'metadata': {'callId': call, 'callAttemptId': 'attempt-$call'},
          },
        },
);
void project(CommittedReplyNarration join, List<LedgerEvent> facts) =>
    join.project(facts, ConversationMessages.project(facts));

void main() {
  late CommittedReplyNarration join;
  setUp(() => join = CommittedReplyNarration()..begin('s'));
  test(
    'tool_terminal text and batch receipt at same sequence narrate once',
    () {
      final fact = LedgerEvent(
        eventId: 'batch-final',
        sessionId: 's',
        sequence: 8,
        type: 'ASSISTANT_TURN_COMMITTED',
        schemaVersion: 1,
        payload: {
          'finishReason': 'tool_terminal',
          'text': '两路处理完成。',
          'batchCallResult': {
            'batchId': 'batch',
            'status': 'COMPLETED',
            'items': [
              {'itemId': 'i', 'status': 'SUCCESS'},
            ],
          },
        },
      );
      join.terminal(terminal(call: 'batch', batch: true));
      project(join, [fact]);
      expect(join.take(), '两路处理完成。');
      join.committed(fact);
      join.terminal(terminal(call: 'batch', batch: true));
      project(join, [fact]);
      expect(join.take(), isNull);
    },
  );
  for (final replyFirst in [true, false]) {
    test(
      'joins both orderings: replyFirst=$replyFirst, only after projection',
      () {
        final fact = reply();
        if (replyFirst) {
          join.committed(fact);
        } else {
          join.terminal(terminal());
        }
        expect(join.take(), isNull);
        if (replyFirst) {
          join.terminal(terminal());
        } else {
          join.committed(fact);
        }
        expect(join.take(), isNull);
        project(join, [fact]);
        expect(join.take(), '持久结果。');
        join.committed(fact);
        join.terminal(terminal());
        project(join, [fact]);
        expect(join.take(), isNull);
      },
    );
  }
  test(
    'sync fallback matches call and selects latest visible result after receipt',
    () {
      join.deferred('call');
      project(join, [
        reply(id: 'old', sequence: 1),
        receipt(sequence: 2),
        reply(id: 'new', sequence: 3),
      ]);
      expect(join.take(), '持久结果。');
      join.deferred('call');
      expect(join.take(), isNull);
    },
  );
  test('no matching terminal identity cannot narrate synchronized history', () {
    join.deferred('another');
    project(join, [receipt(), reply()]);
    expect(join.take(), isNull);
  });
  test('history alone, transient projection, blank reply do not narrate', () {
    final fact = reply();
    project(join, [receipt(), fact]);
    expect(join.take(), isNull);
    join.terminal(terminal());
    join.committed(fact);
    join.project(
      [fact],
      [
        ConversationMessage(
          id: 'ledger:reply',
          role: MessageRole.assistant,
          text: fact.payload['text']! as String,
          transient: true,
        ),
      ],
    );
    expect(join.take(), isNull);
    join.begin('s');
    join.committed(reply(text: ' '));
    join.terminal(terminal());
    project(join, [reply(text: ' ')]);
    expect(join.take(), isNull);
  });
  test('call/batch finish reason and foreign sessions stay separate', () {
    join.committed(reply());
    join.terminal(terminal(batch: true));
    project(join, [reply()]);
    expect(join.take(), isNull);
    final batch = reply(id: 'batch', reason: 'batch_call_result');
    join.committed(batch);
    project(join, [batch]);
    expect(join.take(), '持久结果。');
    join.begin('s');
    join.terminal(terminal(session: 'foreign'));
    join.committed(reply(id: 'foreign', session: 'foreign'));
    project(join, [reply(id: 'foreign', session: 'foreign')]);
    expect(join.take(), isNull);
  });
  test('new turn clears pending but keeps terminal/event dedup', () {
    final fact = reply();
    join.committed(fact);
    join.begin('s');
    join.terminal(terminal());
    project(join, [fact]);
    expect(join.take(), isNull);
    join.committed(fact);
    expect(join.take(), '持久结果。');
    join.begin('s');
    join.terminal(terminal());
    join.committed(reply(id: 'new'));
    project(join, [reply(id: 'new')]);
    expect(join.take(), isNull);
  });
  test('clear cannot be rearmed by a late terminal or deferred event', () {
    join.clear();
    join.terminal(terminal());
    join.deferred('call');
    join.committed(reply());
    project(join, [receipt(), reply()]);
    expect(join.take(), isNull);
  });
  test('bounded dedup permits eviction only after 128 identities', () {
    for (var i = 0; i < 130; i++) {
      final fact = reply(id: 'r$i');
      join.begin('s');
      join.terminal(terminal(call: 'c$i'));
      join.committed(fact);
      project(join, [fact]);
      expect(join.take(), isNotNull);
    }
    join.begin('s');
    join.terminal(terminal(call: 'c0'));
    join.committed(reply(id: 'r0'));
    project(join, [reply(id: 'r0')]);
    expect(join.take(), isNotNull);
  });
}
