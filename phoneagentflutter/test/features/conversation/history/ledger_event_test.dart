import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/history/ledger_event.dart';

void main() {
  LedgerEvent event({
    String id = 'e1',
    String session = 's1',
    int sequence = 1,
    String command = 'c1',
    String text = '回答',
    Map<String, Object?> metadata = const {},
  }) => LedgerEvent(
    eventId: id,
    sessionId: session,
    sequence: sequence,
    type: 'ASSISTANT_TURN_COMMITTED',
    schemaVersion: 1,
    commandId: command,
    payload: {'text': text},
    metadata: metadata,
  );

  test('live comparison ignores only the two storage timestamp fields', () {
    final live = event(metadata: {'occurredAt': 'a', 'committedAt': 'b'});
    final stored = event(metadata: {'occurredAt': 'c', 'committedAt': 'd'});
    expect(live.contentFingerprint, stored.contentFingerprint);
    expect(live.fingerprint, isNot(stored.fingerprint));
  });

  test('content and ownership conflicts remain detectable', () {
    final baseline = event();
    final conflicts = [
      event(id: 'e2'),
      event(session: 's2'),
      event(sequence: 2),
      event(command: 'c2'),
      event(text: '不同回答'),
      event(metadata: {'actor': 'different'}),
    ];
    for (final conflict in conflicts) {
      expect(conflict.contentFingerprint, isNot(baseline.contentFingerprint));
    }
  });
}
