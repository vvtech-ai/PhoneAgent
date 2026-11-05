import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/history/ledger_event.dart';
import 'package:phone_agent/features/conversation/domain/history/ledger_sync.dart';
import 'package:phone_agent/features/conversation/domain/history/timeline_request_failure.dart';

const projection = LedgerProjection(
  status: 'CLOSED',
  continuable: false,
  pendingRestorable: false,
  migrationStatus: 'CURRENT',
  projectedThrough: 3,
);
LedgerEvent event(
  int n, {
  String? id,
  String session = 's',
  String text = 'hello',
  String type = 'USER_TURN_ACCEPTED',
}) => LedgerEvent(
  eventId: id ?? 'e$n',
  sessionId: session,
  sequence: n,
  type: type,
  schemaVersion: 1,
  payload: {'text': text},
);
LedgerPage page(
  List<LedgerEvent> events, {
  int head = 3,
  bool more = false,
  int? next,
  String session = 's',
}) => LedgerPage(
  sessionId: session,
  head: head,
  hasMore: more,
  nextAfter: next,
  projection: projection,
  events: events,
);

class Source implements TimelineSource {
  Source(this.pages);
  final List<LedgerPage> pages;
  final cursors = <int?>[];
  @override
  Future<LedgerPage> load(
    String sessionId, {
    int? afterSequence,
    int limit = 100,
  }) async {
    cursors.add(afterSequence);
    return pages.removeAt(0);
  }
}

class RecoverySource extends Source {
  RecoverySource(super.pages);
  int failures = 0;
  @override
  Future<LedgerPage> load(String id, {int? afterSequence, int limit = 100}) {
    if (failures > 0) {
      failures--;
      cursors.add(afterSequence);
      throw const TimelineRequestFailure(
        'TIMELINE_CURSOR_AHEAD',
        retryable: false,
        recoveryAction: 'FULL_RESYNC',
      );
    }
    return super.load(id, afterSequence: afterSequence, limit: limit);
  }
}

void main() {
  test('server full resync recovery resets cached cursor once only', () async {
    final source = RecoverySource([
      page([event(1)], head: 1),
      page([event(1), event(2)], head: 2),
    ]);
    final owner = LedgerSync(source);
    await owner.sync('a', 's');
    source.failures = 1;
    expect((await owner.sync('a', 's')).cursor, 2);
    expect(source.cursors, [null, 1, null]);
    source.failures = 2;
    await expectLater(
      owner.sync('a', 's'),
      throwsA(isA<TimelineRequestFailure>()),
    );
    expect(source.cursors.sublist(3), [2, null]);
  });
  test(
    'pages sorted and exact duplicates deduplicated without losing unknown events',
    () async {
      final source = Source([
        page([event(2), event(1)], more: true, next: 2),
        page([event(2), event(3, type: 'FUTURE_EVENT')]),
      ]);
      final result = await LedgerSync(source).sync('account', 's');
      expect(result.events.map((e) => e.sequence), [1, 2, 3]);
      expect(result.events.last.type, 'FUTURE_EVENT');
      expect(source.cursors, [null, 2]);
      expect(result.projection.status, 'CLOSED');
    },
  );
  test('gap is fully refetched once only', () async {
    final source = Source([
      page([event(2)], head: 2),
      page([event(1), event(2)], head: 2),
    ]);
    final result = await LedgerSync(source).sync('a', 's');
    expect(result.cursor, 2);
    expect(source.cursors, [null, null]);
    final broken = Source([
      page([event(2)], head: 2),
      page([event(2)], head: 2),
    ]);
    await expectLater(
      LedgerSync(broken).sync('a', 's'),
      throwsA(TimelineFailure.sequenceGap),
    );
    expect(broken.cursors.length, 2);
  });
  test('cache advances and account key isolates', () async {
    final source = Source([
      page([event(1)], head: 1),
      page([event(2)], head: 2),
      page([event(1)], head: 1),
    ]);
    final sync = LedgerSync(source);
    await sync.sync('a', 's');
    expect((await sync.sync('a', 's')).events.length, 2);
    await sync.sync('b', 's');
    expect(source.cursors, [null, 1, null]);
  });
  test(
    'duplicate id with conflicting payload triggers refetch instead of merge',
    () async {
      final source = Source([
        page([event(1), event(1, text: 'other')], head: 1),
        page([event(1, text: 'resolved')], head: 1),
      ]);
      final result = await LedgerSync(source).sync('a', 's');
      expect(result.events.single.payload['text'], 'resolved');
      expect(source.cursors.length, 2);
    },
  );
  test('bad session cannot become compatibility history', () async {
    await expectLater(
      LedgerSync(
        Source([
          page([event(1, session: 'other')], head: 1),
        ]),
      ).sync('a', 's'),
      throwsA(TimelineFailure.invalidResponse),
    );
  });
  test('stalled pagination fails without unbounded calls', () async {
    final source = Source([
      page([event(1)], head: 2, more: true, next: 0),
    ]);
    await expectLater(
      LedgerSync(source).sync('a', 's'),
      throwsA(TimelineFailure.cursorStalled),
    );
    expect(source.cursors.length, 1);
  });
  test(
    'empty ledger explicit legacy signal not successful blank history',
    () async {
      await expectLater(
        LedgerSync(Source([page([], head: 0)])).sync('a', 's'),
        throwsA(TimelineFailure.legacyNoLedger),
      );
    },
  );
  test(
    'metadata immutable and payload ordering does not cause false conflict',
    () {
      final a = LedgerEvent(
        eventId: 'e',
        sessionId: 's',
        sequence: 1,
        type: 'unknown',
        schemaVersion: 2,
        payload: {
          'b': 2,
          'a': {'y': 1, 'x': 2},
        },
      );
      final b = LedgerEvent(
        eventId: 'e',
        sessionId: 's',
        sequence: 1,
        type: 'unknown',
        schemaVersion: 2,
        payload: {
          'a': {'x': 2, 'y': 1},
          'b': 2,
        },
      );
      expect(a.fingerprint, b.fingerprint);
      expect(() => a.payload['x'] = 2, throwsUnsupportedError);
    },
  );
}
