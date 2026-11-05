import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/dialer/data/app_call_record_codec.dart';
import 'package:phone_agent/features/dialer/data/app_dial_recent_source.dart';
import 'package:phone_agent/features/dialer/data/secure_app_call_record_repository.dart';
import 'package:phone_agent/features/dialer/domain/app_call_record_repository.dart';
import 'package:phone_agent/features/dialer/domain/dial_recent_call.dart';
import 'package:phone_agent/features/dialer/data/dial_recent_sources.dart';
import 'package:phone_agent/features/dialer/domain/dial_recent_source.dart';
import 'package:phone_agent/features/dialer/presentation/controller/dial_recent_controller.dart';
import 'app_call_record_repository_test.dart' show record;

void main() {
  late Map<String, String> values;
  late Future<List<DialRecentCall>> Function() legacy;
  var reads = 0, writes = 0;
  var current = true, failWrite = false;
  var sequence = 0;
  late String account;
  SecureAppCallRecordRepository create({String? owner}) {
    final repo = SecureAppCallRecordRepository(
      environment: 'prod',
      apiBase: 'https://synthetic.invalid/',
      accountId: owner ?? account,
      isCurrent: () => current,
      read: (key) async => values[key],
      write: (key, value) async {
        writes++;
        if (failWrite) throw StateError('synthetic');
        values[key] = value;
      },
      readLegacy: () {
        reads++;
        return legacy();
      },
    );
    addTearDown(repo.close);
    return repo;
  }

  setUp(() {
    values = {};
    reads = 0;
    writes = 0;
    current = true;
    failWrite = false;
    account = 'synthetic-${sequence++}';
    legacy = () async => [record('legacy')];
  });

  test(
    'import is persisted before return and fresh instance never rereads old source',
    () async {
      final repo = create();
      expect((await repo.load()).single.id, 'legacy');
      expect(
        AppCallRecordCodec.decode(repo.scope, values[repo.key]).single.id,
        'legacy',
      );
      expect((await create().load()).single.id, 'legacy');
      expect(reads, 1);
      expect(writes, 1);
    },
  );
  test('existing new data and empty envelope are authoritative', () async {
    final repo = create();
    values[repo.key] = AppCallRecordCodec.encode(repo.scope, [record('new')]);
    expect((await repo.load()).single.id, 'new');
    await repo.clear();
    expect(await create().load(), isEmpty);
    expect(reads, 0);
  });
  test(
    'clear before first load consumes source once and cannot resurrect after restart',
    () async {
      await create().clear();
      expect(await create().load(), isEmpty);
      expect(reads, 1);
      expect(writes, 2);
    },
  );
  test(
    'append before first load preserves old rows and deduplicates same call kind',
    () async {
      final repo = create();
      await repo.append(record('new'));
      await repo.append(record('legacy'));
      expect((await repo.load()).map((r) => r.id), ['new', 'legacy']);
      expect(reads, 1);
      expect(writes, 2);
    },
  );
  test('no old rows is durably empty rather than repeatedly reading', () async {
    legacy = () async => [];
    expect(await create().load(), isEmpty);
    expect(await create().load(), isEmpty);
    expect(reads, 1);
    expect(writes, 1);
  });
  test('legacy read failure leaves target absent and can retry', () async {
    final repo = create();
    legacy = () async => throw const AppCallRecordFailure('legacy-unavailable');
    await expectLater(repo.load(), throwsA(isA<AppCallRecordFailure>()));
    expect(values, isEmpty);
    expect(writes, 0);
    legacy = () async => [record('legacy')];
    expect((await repo.load()).single.id, 'legacy');
    expect(reads, 2);
  });
  test('failed target write is not returned as successful import', () async {
    final repo = create();
    failWrite = true;
    await expectLater(repo.load(), throwsA(isA<AppCallRecordFailure>()));
    expect(values, isEmpty);
    failWrite = false;
    expect((await repo.load()).single.id, 'legacy');
    expect(reads, 2);
  });
  test(
    'new malformed payload is never overwritten or replaced by old data',
    () async {
      final repo = create();
      values[repo.key] = 'broken';
      await expectLater(repo.load(), throwsA(isA<AppCallRecordFailure>()));
      await expectLater(repo.clear(), throwsA(isA<AppCallRecordFailure>()));
      expect(reads, 0);
      expect(writes, 0);
      expect(values[repo.key], 'broken');
    },
  );
  for (final close in [false, true]) {
    test(
      'late source after ${close ? 'close' : 'account change'} cannot write',
      () async {
        final entered = Completer<void>();
        final pending = Completer<List<DialRecentCall>>();
        legacy = () {
          entered.complete();
          return pending.future;
        };
        final repo = create();
        final checked = expectLater(
          repo.load(),
          throwsA(isA<AppCallRecordFailure>()),
        );
        await entered.future;
        if (close) {
          repo.close();
        } else {
          current = false;
        }
        pending.complete([record('late')]);
        await checked;
        expect(writes, 0);
      },
    );
  }
  test(
    'cross-instance import, append and clear serialize without resurrection',
    () async {
      final entered = Completer<void>();
      final pending = Completer<List<DialRecentCall>>();
      legacy = () {
        entered.complete();
        return pending.future;
      };
      final first = create(), other = create();
      final loading = first.load();
      await entered.future;
      final appending = other.append(record('new'));
      final cleared = first.clear();
      expect(writes, 0);
      pending.complete([record('legacy')]);
      await loading;
      await appending;
      await cleared;
      expect(await create().load(), isEmpty);
      expect(reads, 1);
      expect(writes, 3);
    },
  );
  test(
    'accounts use independent new slots; source wiring is account specific',
    () async {
      final first = create();
      await first.load();
      legacy = () async => [record('other')];
      final second = create(owner: 'other');
      await second.load();
      expect(first.key, isNot(second.key));
      expect((await first.load()).single.id, 'legacy');
      expect((await second.load()).single.id, 'other');
      expect(reads, 2);
    },
  );
  test(
    'recent consumer still projects only translations and success emits once',
    () async {
      legacy = () async => [
        record('normal', kind: DialRecentKind.normal),
        record('translation'),
      ];
      final repo = create();
      var events = 0;
      final subscription = repo.changes.listen((_) => events++);
      addTearDown(subscription.cancel);
      final source = AppDialRecentSource(repo);
      expect((await source.load()).records.single.id, 'translation');
      await Future<void>.delayed(Duration.zero);
      await source.load();
      await Future<void>.delayed(Duration.zero);
      expect(events, 1);
      expect(reads, 1);
    },
  );
  test(
    'migration change notification settles recent controller without reload loop',
    () async {
      final repo = create();
      final controller = DialRecentController(
        const UnavailableDialRecentSource(DialRecentAccess.unsupported),
        AppDialRecentSource(repo),
      );
      addTearDown(controller.dispose);
      await controller.load();
      await Future<void>.delayed(Duration.zero);
      expect(controller.state.loading, isFalse);
      expect(controller.state.records.single.id, 'legacy');
      expect(reads, 1);
      expect(writes, 1);
    },
  );
}
