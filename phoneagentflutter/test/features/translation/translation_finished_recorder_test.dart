import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/dialer/data/app_call_record_codec.dart';
import 'package:phone_agent/features/dialer/domain/app_call_record_repository.dart';
import 'package:phone_agent/features/dialer/domain/dial_recent_call.dart';
import 'package:phone_agent/features/translation/domain/translation_call_finished.dart';
import 'package:phone_agent/features/translation/presentation/controller/translation_finished_recorder.dart';
import '../dialer/app_call_record_repository_test.dart' show MemoryRecords;

TranslationCallFinished finished(String id, {String account = 'owner'}) =>
    TranslationCallFinished(
      context: TranslationCallContext(
        clientCallId: id,
        targetName: '合成联系人',
        countryIso: 'US',
      ),
      accountId: account,
      phone: '+12025550101',
      callerLanguage: 'zh',
      peerLanguage: 'en',
      startedAtMillis: 10,
      endedAtMillis: 40,
      connectedAtMillis: 20,
      failed: false,
    );

class CountingRecords implements AppCallRecordRepository {
  final rows = <DialRecentCall>[];
  int attempts = 0;
  bool fail = false;
  Completer<void>? gate;
  @override
  Future<void> append(DialRecentCall record) async {
    attempts++;
    await gate?.future;
    if (fail) throw StateError('private error');
    rows.add(record);
  }

  @override
  Future<List<DialRecentCall>> load() async => rows;
  @override
  Future<void> clear() async => rows.clear();
  @override
  Stream<void> get changes => const Stream.empty();
  @override
  void close() {}
}

void main() {
  TranslationFinishedRecorder create(
    AppCallRecordRepository? repo, {
    bool Function()? current,
  }) {
    final recorder = TranslationFinishedRecorder(
      accountId: 'owner',
      repository: repo,
      isCurrent: current ?? () => true,
    );
    addTearDown(() {
      if (recorder.mounted) recorder.dispose();
    });
    return recorder;
  }

  test('context identity is fresh; local codec contains metadata only', () {
    final contexts = List.generate(100, (_) => TranslationCallContext.create());
    expect(contexts.map((e) => e.clientCallId).toSet(), hasLength(100));
    final row = finished('1').record;
    expect(row.kind, DialRecentKind.translation);
    expect(row.name, '合成联系人');
    expect(row.startedAtMillis, 10);
    final raw = AppCallRecordCodec.encode('scope', [row]);
    for (final private in [
      'grant',
      'transcript',
      'settlement',
      'accountId',
      'connectedAtMillis',
    ]) {
      expect(raw, isNot(contains(private)));
    }
  });
  test(
    'one append across in-flight, terminal replay and explicit retry',
    () async {
      final repo = CountingRecords()..gate = Completer<void>();
      final recorder = create(repo);
      recorder.accept(finished('1'));
      await Future<void>.delayed(Duration.zero);
      recorder.accept(finished('1'));
      final retry = recorder.retry();
      repo.gate!.complete();
      await retry;
      recorder.accept(finished('1'));
      await recorder.retry();
      expect(repo.attempts, 1);
      expect(recorder.snapshot.failedCount, 0);
    },
  );
  test(
    'failure remains explicit and sanitized; retry never replays successful records',
    () async {
      final repo = CountingRecords()..fail = true;
      final recorder = create(repo);
      recorder.accept(finished('1'));
      await recorder.idle;
      expect(recorder.snapshot.failedCount, 1);
      expect(recorder.snapshot.error, isNot(contains('private')));
      repo.fail = false;
      recorder.accept(finished('2'));
      await recorder.idle;
      expect(repo.attempts, 2);
      expect(recorder.snapshot.failedCount, 1);
      await recorder.retry();
      await recorder.retry();
      expect(repo.rows.map((e) => e.id), ['2', '1']);
      expect(repo.attempts, 3);
    },
  );
  test('synchronous idle listener enqueue is not stranded', () async {
    final repo = CountingRecords();
    final recorder = create(repo);
    var enqueue = true;
    recorder.addListener((state) {
      if (!state.saving && enqueue) {
        enqueue = false;
        recorder.accept(finished('2'));
      }
    }, fireImmediately: false);
    recorder.accept(finished('1'));
    await recorder.idle;
    expect(repo.rows.map((e) => e.id), ['1', '2']);
  });
  test('foreign, unavailable and expired account callbacks ignored', () async {
    final repo = CountingRecords();
    var current = true;
    final recorder = create(repo, current: () => current);
    recorder.accept(finished('1', account: 'other'));
    current = false;
    recorder.accept(finished('2'));
    await recorder.retry();
    create(null).accept(finished('3'));
    expect(repo.attempts, 0);
  });
  test(
    'account switch during actual repository read prevents persistent write',
    () async {
      final memory = MemoryRecords()..readGate = Completer<void>();
      final recorder = create(memory.create(), current: () => memory.current);
      recorder.accept(finished('1'));
      await Future<void>.delayed(Duration.zero);
      memory.current = false;
      memory.readGate!.complete();
      await recorder.idle;
      expect(memory.writes, 0);
    },
  );
  test('dispose during save ignores late failure and clears retries', () async {
    final repo = CountingRecords()
      ..gate = Completer<void>()
      ..fail = true;
    final recorder = create(repo);
    recorder.accept(finished('1'));
    await Future<void>.delayed(Duration.zero);
    recorder.dispose();
    repo.gate!.complete();
    await recorder.idle;
    await recorder.retry();
    expect(repo.attempts, 1);
  });
}
