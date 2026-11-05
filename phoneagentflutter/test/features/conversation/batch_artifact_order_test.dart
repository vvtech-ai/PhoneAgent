import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/artifacts/task_artifact_projection.dart';
import 'package:phone_agent/features/conversation/domain/conversation_message_merge.dart';
import 'package:phone_agent/features/conversation/domain/conversation_messages.dart';
import 'package:phone_agent/features/conversation/domain/history/ledger_event.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_message_store.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_state.dart';

Map<String, Object?> csv(String batch) => {
  'artifactId': 'batch-receipt-csv.session.$batch',
  'kind': 'BATCH_RECEIPT_CSV',
  'fileName': '$batch.csv',
  'mimeType': 'text/csv',
  'status': 'READY',
  'sourceBatchId': batch,
  'itemCount': 2,
};

Map<String, Object?> result(String batch) => {
  'type': 'BATCH_CALL_RESULT',
  'batchCallResult': {
    'batchId': batch,
    'status': 'COMPLETED',
    'totalCount': 2,
    'items': [
      {'itemId': '$batch-1', 'status': 'SUCCESS'},
      {'itemId': '$batch-2', 'status': 'FAILED'},
    ],
    'artifacts': [csv(batch)],
  },
};

LedgerEvent fact(int sequence, String command, Map<String, Object?> payload) =>
    LedgerEvent(
      eventId: 'e$sequence',
      sessionId: 'session',
      sequence: sequence,
      type: 'ASSISTANT_TURN_COMMITTED',
      schemaVersion: 1,
      commandId: command,
      payload: payload,
    );

List<String> order(List<ConversationMessage> messages) => [
  for (final message in messages)
    if (message.batchReceipt != null)
      'batch:${message.batchReceipt!.id}'
    else if (message.artifact != null)
      message.artifact!.fileName
    else
      message.text,
];

void main() {
  test(
    'history keeps each CSV after its own result and deduplicates replay',
    () {
      final messages = ConversationMessages.project([
        fact(1, 'a', result('a')),
        fact(2, 'b', result('b')),
        fact(3, 'a', {'artifact': csv('a')}),
      ]);
      expect(order(messages), ['batch:a', 'a.csv', 'batch:b', 'b.csv']);
    },
  );

  test(
    'early live artifact moves behind its result before and after commit',
    () {
      final store = ConversationMessageStore();
      const state = ConversationState(
        entry: ConversationEntry(sessionId: 'session'),
      );
      store.artifacts({'artifact': csv('a')}, 'a');
      store.finish(result('a'), 'a');
      expect(order(store.project(state).messages), ['batch:a', 'a.csv']);
      store.facts['e1'] = fact(1, 'a', result('a'));
      expect(order(store.project(state).messages), ['batch:a', 'a.csv']);
    },
  );

  test('merge associates only CSV artifacts, preserving template and orphan', () {
    final template = TaskArtifactProjection.messages({
      'artifact': {
        'artifactId': 'skill-template:meeting:v1',
        'kind': 'SKILL_TEMPLATE',
        'fileName': '模板.docx',
        'mimeType':
            'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        'status': 'READY',
      },
    }, 'a').single;
    final orphan = TaskArtifactProjection.messages({
      'artifact': csv('other'),
    }, 'a');
    final batch = ConversationMessages.project([
      fact(1, 'a', result('a')),
    ]).where((m) => m.batchReceipt != null).single;
    final artifact = TaskArtifactProjection.messages({
      'artifact': csv('a'),
    }, 'a');
    final merged = ConversationMessageMerge.merge([], [
      template,
      ...artifact,
      batch,
      ...orphan,
    ]);
    expect(order(merged), ['模板.docx', 'batch:a', 'a.csv', 'other.csv']);
  });
}
