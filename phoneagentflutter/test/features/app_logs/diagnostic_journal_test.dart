import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/diagnostics/diagnostic_event.dart';
import 'package:phone_agent/core/diagnostics/diagnostic_journal.dart';

DiagnosticEvent event(int elapsed) => DiagnosticEvent(
  operation: DiagnosticOperation.accountRequest,
  result: DiagnosticResult.succeeded,
  elapsedMs: elapsed,
);

void main() {
  test('immediate flush persists without waiting for delayed batch', () async {
    final store = _Store();
    final journal = DiagnosticJournal(
      store,
      flushDelay: const Duration(days: 1),
    );
    addTearDown(journal.close);
    journal.record(event(1));
    expect(store.writes, 0);
    await journal.flush();
    expect(store.writes, 1);
    expect((jsonDecode(store.value!)['events'] as List).length, 1);
  });

  test(
    'flush after close does not re-open or append to closed journal',
    () async {
      final store = _Store();
      final journal = DiagnosticJournal(store);
      journal.record(event(1));
      journal.close();
      journal.record(event(2));
      await journal.flush();
      expect(store.writes, 1);
      expect(
        (jsonDecode(store.value!)['events'] as List).single['elapsedMs'],
        1,
      );
    },
  );
  test('white list removes nonUUID identifiers and unknown stored fields', () {
    final value = DiagnosticEvent(
      operation: DiagnosticOperation.agentStream,
      result: DiagnosticResult.failed,
      sessionId: '+8618811111111',
      traceId: 'Bearer synthetic-secret',
      statusCode: 900,
      elapsedMs: -1,
    );
    final raw = value.toJson()..['message'] = 'private';
    final restored = DiagnosticEvent.fromJson(raw).toJson();
    final encoded = jsonEncode(restored);
    expect(restored.keys.toSet(), {
      'operation',
      'result',
      'time',
      'statusCode',
      'elapsedMs',
    });
    expect(encoded, isNot(contains('private')));
    expect(encoded, isNot(contains('+8618811111111')));
    expect(encoded, isNot(contains('secret')));
    expect(value.toJson()['statusCode'], 599);
    expect(value.toJson()['elapsedMs'], 0);
  });
  test(
    'agent stream keeps generated opaque IDs for HTTP error correlation',
    () {
      const session = '242bde9b7e5803b278201fcb09f3ed08';
      const trace = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
      final event = DiagnosticEvent(
        operation: DiagnosticOperation.agentStream,
        result: DiagnosticResult.failed,
        sessionId: session,
        traceId: trace,
        statusCode: 503,
      );
      final restored = DiagnosticEvent.fromJson(event.toJson());
      expect(restored.sessionId, session);
      expect(restored.traceId, trace);
      expect(restored.statusCode, 503);
    },
  );
  test(
    'journal survives recreation and keeps only bounded latest events',
    () async {
      final store = _Store();
      final first = DiagnosticJournal(store, capacity: 3);
      addTearDown(first.close);
      for (var i = 0; i < 8; i++) {
        first.record(event(i));
      }
      final snapshot = await first.snapshot();
      expect(snapshot.events.map((e) => e.elapsedMs), [5, 6, 7]);
      final second = DiagnosticJournal(store, capacity: 3);
      addTearDown(second.close);
      expect((await second.snapshot()).events.length, 3);
    },
  );
  test('acknowledgement preserves events collected while uploading', () async {
    final journal = DiagnosticJournal(_Store());
    addTearDown(journal.close);
    journal.record(event(1));
    final snapshot = await journal.snapshot();
    journal.record(event(2));
    await journal.acknowledge(snapshot.watermark);
    expect((await journal.snapshot()).events.map((e) => e.elapsedMs), [2]);
  });
  test(
    'read failure never overwrites existing store; retry keeps queued events',
    () async {
      final store = _Store()..readFails = true;
      final journal = DiagnosticJournal(store);
      addTearDown(journal.close);
      journal.record(event(1));
      await expectLater(journal.snapshot(), throwsStateError);
      expect(store.writes, 0);
      store.readFails = false;
      expect((await journal.snapshot()).events.length, 1);
    },
  );
  test('write failure preserves events for a later successful flush', () async {
    final store = _Store()..writeFails = true;
    final journal = DiagnosticJournal(store);
    addTearDown(journal.close);
    journal.record(event(1));
    await expectLater(journal.snapshot(), throwsStateError);
    store.writeFails = false;
    expect((await journal.snapshot()).events.length, 1);
  });
  test(
    'malformed data is not silently replaced and corrected data can load',
    () async {
      final store = _Store()..value = '{"version":1,"events":[{"sequence":2}]}';
      final journal = DiagnosticJournal(store);
      addTearDown(journal.close);
      await expectLater(journal.snapshot(), throwsA(anything));
      expect(store.writes, 0);
      store.value = null;
      journal.record(event(3));
      expect((await journal.snapshot()).events.length, 1);
    },
  );
  test('cleanup persistence failure retains old entries until retry', () async {
    final store = _Store();
    final journal = DiagnosticJournal(store);
    addTearDown(journal.close);
    journal.record(event(1));
    final snapshot = await journal.snapshot();
    store.failAt = store.writes + 2;
    await expectLater(
      journal.acknowledge(snapshot.watermark),
      throwsStateError,
    );
    expect((await journal.snapshot()).events.length, 1);
    await journal.acknowledge(snapshot.watermark);
    expect((await journal.snapshot()).events, isEmpty);
  });
  test('diagnostic sink exceptions do not escape to business flow', () {
    expect(
      () => emitDiagnostic((_) => throw StateError('sink'), event(1)),
      returnsNormally,
    );
  });
}

class _Store implements DiagnosticStore {
  String? value;
  bool readFails = false, writeFails = false;
  int writes = 0, failAt = -1;
  @override
  Future<String?> read() async {
    if (readFails) throw StateError('read');
    return value;
  }

  @override
  Future<void> write(String text) async {
    writes++;
    if (writeFails || writes == failAt) throw StateError('write');
    value = text;
  }
}
