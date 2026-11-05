import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/calls/data/secure_call_admission_notice_store.dart';
import 'package:phone_agent/features/calls/domain/call_admission.dart';
import 'package:phone_agent/features/calls/domain/call_admission_service.dart';
import '../../support/call_admission_fixture.dart';

void main() {
  late Map<String, String> disk;
  var reads = 0, failRead = false, failWrite = false, current = true;
  late Future<Set<String>> Function(String, Iterable<String>) legacy;
  SecureCallAdmissionNoticeStore make({String account = 'a'}) =>
      SecureCallAdmissionNoticeStore(
        environment: 'prod|synthetic',
        accountId: account,
        isCurrent: () => current,
        read: (key) async {
          if (failRead) throw StateError('read');
          return disk[key];
        },
        write: (key, value) async {
          if (failWrite) throw StateError('write');
          disk[key] = value;
        },
        legacyRead: (session, aliases) async {
          reads++;
          return legacy(session, aliases);
        },
      );
  setUp(() {
    disk = {};
    reads = 0;
    failRead = failWrite = false;
    current = true;
    legacy = (_, aliases) async => aliases.toSet();
  });
  test(
    'first import persists true; new marker and new non-1 values win',
    () async {
      expect(await make().wasNotified('s', ['tool']), true);
      expect(disk.values, ['1']);
      expect(await make().wasNotified('s', ['tool']), true);
      expect(reads, 1);
      disk[disk.keys.single] = '0';
      expect(await make().wasNotified('s', ['tool']), false);
      expect(reads, 1);
    },
  );
  test(
    'only missing aliases are queried and no-match writes nothing',
    () async {
      await make().markNotified('s', ['first']);
      disk[disk.keys.single] = '0';
      legacy = (session, aliases) async {
        expect(session, 's');
        expect(aliases, ['second']);
        return {};
      };
      expect(await make().wasNotified('s', ['first', 'second']), false);
      expect(disk.values, ['0']);
    },
  );
  test(
    'read failure never falls back; old source and target failures remain retryable',
    () async {
      failRead = true;
      await expectLater(make().wasNotified('s', ['tool']), throwsStateError);
      expect(reads, 0);
      failRead = false;
      legacy = (_, __) async => throw StateError('source');
      await expectLater(make().wasNotified('s', ['tool']), throwsStateError);
      legacy = (_, aliases) async => aliases.toSet();
      failWrite = true;
      await expectLater(make().wasNotified('s', ['tool']), throwsStateError);
      expect(disk, isEmpty);
      failWrite = false;
      expect(await make().wasNotified('s', ['tool']), true);
    },
  );
  test('foreign legacy alias is rejected without persistence', () async {
    legacy = (_, __) async => {'other'};
    await expectLater(make().wasNotified('s', ['tool']), throwsFormatException);
    expect(disk, isEmpty);
  });
  test(
    'owner closure during import cannot publish or persist late markers',
    () async {
      final gate = Completer<Set<String>>(), started = Completer<void>();
      legacy = (_, __) {
        started.complete();
        return gate.future;
      };
      final rejected = expectLater(
        make().wasNotified('s', ['tool']),
        throwsStateError,
      );
      await started.future;
      current = false;
      gate.complete({'tool'});
      await rejected;
      expect(disk, isEmpty);
    },
  );
  test(
    'concurrent import and marker writes retain every alias with account separation',
    () async {
      await Future.wait([
        make().wasNotified('s', ['one']),
        make().markNotified('s', ['two']),
        make(account: 'b').markNotified('s', ['one']),
        make().markNotified('other', ['one']),
      ]);
      expect(disk.length, 4);
      expect(await make().wasNotified('s', ['one', 'two']), true);
    },
  );
  test(
    'restored service uses repeated insufficiency and refreshes without posting notices',
    () async {
      final request = callRequest();
      final ports = AdmissionFixture();
      var refreshes = 0;
      final service = CallAdmissionService(
        store: make(),
        notices: ports,
        readBalance: () => 0,
        readModel: () => 'Doubao',
        refreshBalance: () async {
          refreshes++;
          return 0;
        },
      );
      final decision = await service.evaluate(
        request,
        priorRequests: [],
        isCurrent: () => true,
        onlyRepeated: true,
      );
      expect(decision!.kind, CallAdmissionKind.repeatedInsufficient);
      expect(decision.persistenceFailed, false);
      expect(refreshes, 1);
      expect(ports.commits, 0);
      expect(disk.values.toSet(), {'1'});
    },
  );
}
