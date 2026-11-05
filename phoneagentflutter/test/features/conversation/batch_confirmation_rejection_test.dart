import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/batch_confirmation.dart';
import 'package:phone_agent/features/conversation/domain/conversation_messages.dart';
import 'package:phone_agent/features/conversation/domain/history/batch_confirmation_projector.dart';
import 'package:phone_agent/features/conversation/domain/history/conversation_source_steps.dart';
import 'package:phone_agent/features/conversation/domain/history/ledger_event.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_message_store.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_state.dart';

Map<String, Object?> request(String id) => {
  'toolName': 'confirmBatchTask',
  'toolCallId': id,
  'displayPayloadVersion': 1,
  'assistantText': '请确认合成任务',
  'arguments': {
    'snapshotJson': {'title': '合成任务'},
  },
};

LedgerEvent event(
  int sequence,
  String type,
  Map<String, Object?> payload, {
  String session = 'session',
  int schema = 1,
}) => LedgerEvent(
  eventId: '$session:$sequence',
  sessionId: session,
  sequence: sequence,
  type: type,
  schemaVersion: schema,
  commandId: 'command-$sequence',
  payload: payload,
);

Map<String, Object?> result(String id, String status, {String? decision}) => {
  'toolName': 'confirmBatchTask',
  'toolCallId': id,
  'resultStatus': status,
  if (decision != null) 'result': {'decision': decision},
};

void main() {
  for (final status in ['rejected', 'policy_rejected', 'POLICY_REJECTED']) {
    test('$status removes only the rejected batch snapshot from history', () {
      final facts = [
        event(1, 'TOOL_REQUESTED', request('bad')),
        event(2, 'TOOL_RESULT_RECORDED', result('bad', status)),
        event(3, 'TOOL_REQUESTED', request('good')),
      ];
      final cards = BatchConfirmationProjector.project(facts.reversed);
      expect(cards.map((c) => c.confirmation.snapshotId), ['good']);
      final messages = ConversationMessages.project(facts.reversed);
      expect(messages.map((m) => m.toolCallId), ['good']);
      expect(ConversationSourceSteps.project(facts).map((s) => s.id), [
        'ledger:batch-confirmation:good',
      ]);
      expect(ConversationMessages.rejectedCallIds(facts), {'bad'});
    });

    test(
      '$status removes its transient batch card after fact synchronization',
      () {
        final store = ConversationMessageStore();
        for (final id in ['bad', 'good']) {
          store.upsert(
            ConversationMessage(
              id: 'local:$id',
              role: MessageRole.assistant,
              text: '请确认合成任务',
              commandId: 'command-$id',
              toolCallId: id,
              batchConfirmation: BatchConfirmation.request(request(id)),
              transient: true,
            ),
          );
        }
        final rejected = event(
          2,
          'TOOL_RESULT_RECORDED',
          result('bad', status),
        );
        store.facts[rejected.eventId] = rejected;
        final projected = store.project(
          const ConversationState(
            entry: ConversationEntry(sessionId: 'session'),
          ),
        );
        expect(projected.messages.map((m) => m.toolCallId), ['good']);
        expect(store.messages.map((m) => m.toolCallId), ['good']);
      },
    );
  }

  test(
    'foreign session and different tool identity cannot remove a snapshot',
    () {
      final facts = [
        event(1, 'TOOL_REQUESTED', request('same')),
        event(2, 'TOOL_RESULT_RECORDED', result('other', 'rejected')),
        event(
          3,
          'TOOL_RESULT_RECORDED',
          result('same', 'policy_rejected'),
          session: 'foreign',
        ),
      ];
      expect(
        BatchConfirmationProjector.project(
          facts,
        ).single.confirmation.snapshotId,
        'same',
      );
      expect(ConversationSourceSteps.project(facts).map((s) => s.id), [
        'ledger:batch-confirmation:same',
      ]);
      final store = ConversationMessageStore();
      store.upsert(
        ConversationMessage(
          id: 'local:same',
          role: MessageRole.assistant,
          text: '',
          toolCallId: 'same',
          batchConfirmation: BatchConfirmation.request(request('same')),
        ),
      );
      for (final fact in facts.skip(1)) {
        store.facts[fact.eventId] = fact;
      }
      expect(
        store
            .project(
              const ConversationState(
                entry: ConversationEntry(sessionId: 'session'),
              ),
            )
            .messages
            .single
            .toolCallId,
        'same',
      );
    },
  );

  for (final decision in ['CONFIRMED', 'REVISION_REQUESTED', 'CANCELLED']) {
    test('successful $decision keeps the original batch snapshot', () {
      final facts = [
        event(1, 'TOOL_REQUESTED', request('snapshot')),
        event(
          2,
          'TOOL_RESULT_RECORDED',
          result('snapshot', 'completed', decision: decision),
        ),
      ];
      final card = BatchConfirmationProjector.project(
        facts,
      ).single.confirmation;
      expect(card.decision, BatchConfirmationDecision.fromWire(decision));
      expect(ConversationSourceSteps.project(facts), hasLength(1));
    });
  }

  test(
    'rejected result cannot confirm a batch or suppress its execution card',
    () {
      final facts = [
        event(1, 'TOOL_REQUESTED', request('snapshot')),
        event(
          2,
          'TOOL_RESULT_RECORDED',
          result('snapshot', 'rejected', decision: 'CONFIRMED'),
        ),
        event(3, 'TOOL_REQUESTED', {
          'toolName': 'makeBatchCalls',
          'toolCallId': 'execution',
          'arguments': {'primaryGoal': '合成任务'},
        }),
      ];
      expect(BatchConfirmationProjector.executionRequestIds(facts), isEmpty);
      expect(BatchConfirmationProjector.project(facts), isEmpty);
      expect(ConversationSourceSteps.project(facts).map((s) => s.id), [
        'ledger:call-confirmation:execution',
      ]);
    },
  );

  test('unknown schema rejection does not erase a supported snapshot', () {
    final facts = [
      event(1, 'TOOL_REQUESTED', request('snapshot')),
      event(
        2,
        'TOOL_RESULT_RECORDED',
        result('snapshot', 'rejected'),
        schema: 2,
      ),
    ];
    expect(BatchConfirmationProjector.project(facts), hasLength(1));
    expect(ConversationSourceSteps.project(facts), hasLength(1));
    expect(ConversationMessages.rejectedCallIds(facts), isEmpty);
  });
}
