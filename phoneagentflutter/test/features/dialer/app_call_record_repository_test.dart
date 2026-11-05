import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/dialer/data/app_call_record_codec.dart';
import 'package:phone_agent/features/dialer/data/app_dial_recent_source.dart';
import 'package:phone_agent/features/dialer/data/secure_app_call_record_repository.dart';
import 'package:phone_agent/features/dialer/domain/app_call_record_repository.dart';
import 'package:phone_agent/features/dialer/domain/app_dial_history_recorder.dart';
import 'package:phone_agent/features/dialer/domain/dial_recent_call.dart';
import 'package:phone_agent/features/dialer/domain/dial_recent_source.dart';

DialRecentCall record(
  String id, {
  DialRecentKind kind = DialRecentKind.translation,
}) => DialRecentCall(
  id: id,
  phone: '+12025550101',
  name: '合成记录',
  startedAtMillis: 10,
  source: DialRecentSource.app,
  kind: kind,
  countryIso: 'US',
  callerLanguage: 'zh',
  peerLanguage: 'en',
);

class MemoryRecords {
  final values = <String, String>{};
  int reads = 0, writes = 0;
  bool failRead = false, failWrite = false, current = true;
  Completer<void>? readGate;
  SecureAppCallRecordRepository create({
    String env = 'dev',
    String api = 'https://synthetic.invalid/',
    String account = 'synthetic',
  }) {
    final repo = SecureAppCallRecordRepository(
      environment: env,
      apiBase: api,
      accountId: account,
      isCurrent: () => current,
      read: (key) async {
        reads++;
        await readGate?.future;
        if (failRead) throw StateError('sensitive synthetic detail');
        return values[key];
      },
      write: (key, value) async {
        writes++;
        if (failWrite) throw StateError('sensitive synthetic detail');
        values[key] = value;
      },
    );
    addTearDown(repo.close);
    return repo;
  }
}

void main() {
  test('metadata roundtrip, immutable and app identity', () {
    final raw = AppCallRecordCodec.encode('scope', [record('1')]);
    final rows = AppCallRecordCodec.decode('scope', raw);
    expect(rows.single.countryIso, 'US');
    expect(rows.single.callerLanguage, 'zh');
    expect(rows.single.peerLanguage, 'en');
    expect(rows.single.source, DialRecentSource.app);
    expect(() => rows.clear(), throwsUnsupportedError);
    expect(AppCallRecordCodec.decode('scope', null), isEmpty);
    expect(raw, isNot(contains('transcript')));
  });
  for (final raw in [
    '{',
    '{}',
    '{"version":2,"scope":"s","records":[]}',
    '{"version":1,"scope":"other","records":[]}',
  ]) {
    test('invalid envelope is not treated as empty: $raw', () {
      expect(
        () => AppCallRecordCodec.decode('s', raw),
        throwsA(isA<AppCallRecordFailure>()),
      );
    });
  }
  test('invalid rows and foreign source are rejected', () {
    final value =
        jsonDecode(AppCallRecordCodec.encode('s', [record('1')])) as Map;
    (value['records'][0] as Map)['at'] = -1;
    expect(
      () => AppCallRecordCodec.decode('s', jsonEncode(value)),
      throwsA(isA<AppCallRecordFailure>()),
    );
    expect(
      () => AppCallRecordCodec.encode('s', [
        const DialRecentCall(
          id: '1',
          phone: '1',
          startedAtMillis: 1,
          source: DialRecentSource.system,
        ),
      ]),
      throwsA(isA<AppCallRecordFailure>()),
    );
  });
  test('environment API and account are separately scoped', () async {
    final memory = MemoryRecords();
    final owners = [
      memory.create(),
      memory.create(env: 'prod'),
      memory.create(api: 'https://other.invalid/'),
      memory.create(account: 'other'),
    ];
    expect(owners.map((r) => r.key).toSet().length, 4);
    await owners.first.append(record('1'));
    for (final owner in owners.skip(1)) {
      expect(await owner.load(), isEmpty);
    }
    expect(owners.first.key, isNot(contains('synthetic')));
    expect((await memory.create().load()).single.id, '1');
  });
  test('concurrent read modify write is serialized across instances', () async {
    final memory = MemoryRecords();
    final first = memory.create(), second = memory.create();
    await Future.wait([
      first.append(record('a')),
      second.append(record('b')),
      first.clear(),
      second.append(record('c')),
    ]);
    expect((await first.load()).map((r) => r.id), ['c']);
  });
  test('same id and kind deduplicates, other kind remains distinct', () async {
    final memory = MemoryRecords();
    final repo = memory.create();
    await repo.append(record('1'));
    await repo.append(record('1'));
    await repo.append(record('1', kind: DialRecentKind.normal));
    expect((await repo.load()).length, 2);
    expect(memory.writes, 2);
  });
  test(
    'unknown or corrupt persisted data is never overwritten by clear or append',
    () async {
      final memory = MemoryRecords();
      final repo = memory.create();
      memory.values[repo.key] = 'unknown-schema';
      await expectLater(repo.clear(), throwsA(isA<AppCallRecordFailure>()));
      await expectLater(
        repo.append(record('1')),
        throwsA(isA<AppCallRecordFailure>()),
      );
      expect(memory.writes, 0);
      expect(memory.values[repo.key], 'unknown-schema');
    },
  );
  test(
    'write failure preserves stored data, emits no success and permits retry',
    () async {
      final memory = MemoryRecords();
      final repo = memory.create();
      var events = 0;
      final sub = repo.changes.listen((_) => events++);
      addTearDown(sub.cancel);
      await repo.append(record('1'));
      memory.failWrite = true;
      await expectLater(
        repo.clear(),
        throwsA(
          predicate(
            (e) =>
                e is AppCallRecordFailure &&
                !e.toString().contains('sensitive'),
          ),
        ),
      );
      expect((await repo.load()).length, 1);
      memory.failWrite = false;
      await repo.clear();
      await Future<void>.delayed(Duration.zero);
      expect(events, 2);
      expect(await repo.load(), isEmpty);
    },
  );
  test('owner changed while read is pending prevents old write', () async {
    final memory = MemoryRecords()..readGate = Completer();
    final repo = memory.create();
    final pending = repo.append(record('1'));
    final check = expectLater(pending, throwsA(isA<AppCallRecordFailure>()));
    await Future<void>.delayed(Duration.zero);
    memory.current = false;
    memory.readGate!.complete();
    await check;
    expect(memory.writes, 0);
  });
  test('closed repository fails safely and does not access storage', () async {
    final memory = MemoryRecords();
    final repo = memory.create()..close();
    await expectLater(repo.load(), throwsA(isA<AppCallRecordFailure>()));
    expect(memory.reads, 0);
  });
  test(
    'formal recent source selects translations and exposes failure',
    () async {
      final memory = MemoryRecords();
      final repo = memory.create();
      await repo.append(record('translation'));
      await repo.append(record('normal', kind: DialRecentKind.normal));
      await repo.append(record('agent', kind: DialRecentKind.agent));
      final source = AppDialRecentSource(repo);
      expect((await source.load()).records.map((r) => r.id), ['translation']);
      memory.failRead = true;
      expect((await source.load()).access, DialRecentAccess.failed);
    },
  );
  test(
    'ordinary handoff records metadata but is not a translation recent row',
    () async {
      final memory = MemoryRecords();
      final repo = memory.create();
      final recorder = AppDialHistoryRecorder(
        repo,
        now: () => DateTime.fromMillisecondsSinceEpoch(123),
        nextId: () => 'handoff',
      );
      await recorder.systemHandoff('+12025550101', '合成联系人', 'US');
      final row = (await repo.load()).single;
      expect(row.id, 'handoff');
      expect(row.startedAtMillis, 123);
      expect(row.kind, DialRecentKind.normal);
      expect(row.name, '合成联系人');
      expect((await AppDialRecentSource(repo).load()).records, isEmpty);
    },
  );
}
