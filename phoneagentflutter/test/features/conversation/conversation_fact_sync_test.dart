import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/calls/data/preview_call_flow.dart';
import 'package:phone_agent/features/conversation/domain/history/ledger_event.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_fact_sync.dart';

LedgerEvent fact(
  int sequence, {
  String? id,
  String session = 's',
  String text = 'synthetic',
  String timestamp = '2026-09-17T01:00:00.123456Z',
  String owner = 'synthetic-owner',
}) => LedgerEvent(
  eventId: id ?? 'e$sequence',
  sessionId: session,
  sequence: sequence,
  type: 'ASSISTANT_TEXT_COMMITTED',
  schemaVersion: 1,
  payload: {'text': text},
  metadata: {'occurredAt': timestamp, 'committedAt': timestamp, 'owner': owner},
);

LedgerSnapshot ledger(List<LedgerEvent> events) => LedgerSnapshot(
  's',
  10,
  const LedgerProjection(
    status: 'ACTIVE',
    continuable: true,
    pendingRestorable: false,
    migrationStatus: 'NATIVE',
    projectedThrough: 10,
  ),
  events,
);

void main() {
  test('REST normalization replaces live timestamps and retains newer SSE', () {
    final live = fact(1), newer = fact(2);
    final stored = fact(1, timestamp: '2026-09-17T01:00:00.123Z');
    final facts = {'e1': live, 'e2': newer};
    expect(ConversationFactSync.merge(facts, ledger([stored])), isTrue);
    expect(facts['e1'], same(stored));
    expect(facts['e2'], same(newer));
  });
  test('duplicate live timestamp keeps authoritative REST copy', () async {
    final stored = fact(1, timestamp: '2026-09-17T01:00:00.123Z');
    final facts = {'e1': stored};
    expect(
      await ConversationFactSync.accept(
        fact: fact(1),
        facts: facts,
        history: PreviewCallFlow(CallFlowScenario.single),
        sessionId: 's',
        isCurrent: () => true,
      ),
      isTrue,
    );
    expect(facts['e1'], same(stored));
  });
  for (final pair in {
    'payload': fact(1, text: 'changed'),
    'metadata owner': fact(1, owner: 'other'),
    'sequence identity': fact(1, id: 'other'),
    'foreign session': fact(1, session: 'other'),
  }.entries) {
    test('${pair.key} conflict rejects merge atomically', () {
      final original = fact(1);
      final facts = {'e1': original};
      expect(
        ConversationFactSync.merge(facts, ledger([fact(2), pair.value])),
        isFalse,
      );
      expect(facts, {'e1': original});
    });
  }
  test(
    'conflicting duplicates inside a snapshot do not partly mutate facts',
    () {
      final original = fact(1);
      final facts = {'e1': original};
      expect(
        ConversationFactSync.merge(
          facts,
          ledger([fact(2), fact(2, text: 'bad')]),
        ),
        isFalse,
      );
      expect(facts, {'e1': original});
    },
  );
}
