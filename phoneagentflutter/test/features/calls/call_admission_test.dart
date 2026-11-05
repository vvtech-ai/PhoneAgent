import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/calls/domain/call_admission.dart';
import '../../support/call_admission_fixture.dart';

void main() {
  test('stable alias preserves v65 ordinal and raw summary separators', () {
    final request = callRequest(
      ordinal: 2,
      spec: {
        'summaryLines': [' A ', '', ' B '],
        'recipientCount': 0,
      },
    );
    expect(
      request.stableAlias,
      [
        'task-confirmation-v1',
        '2',
        'synthetic',
        '合成联系人',
        '+12025550101',
        '合成目的',
        '0',
        'A \u001e\u001e B',
      ].join('\u0000'),
    );
    expect(request.aliases.first, 'tool');
    expect(request.toString(), 'CallLaunchRequest(redacted)');
    expect(request.stableAlias, isNot(callRequest(ordinal: 3).stableAlias));
  });
  test(
    'same task normalization and absent phone match but scope/count differ',
    () {
      final a = callRequest(spec: {'targetName': ' A B ', 'phoneNumber': ''});
      expect(a.sameTask(callRequest(spec: {'targetName': 'ab'})), isTrue);
      expect(
        a.sameTask(callRequest(session: 'other', spec: {'targetName': 'ab'})),
        isFalse,
      );
      expect(
        a.sameTask(
          callRequest(spec: {'targetName': 'ab', 'recipientCount': 2}),
        ),
        isFalse,
      );
      expect(
        callRequest().sameTask(
          callRequest(spec: {'phoneNumber': '+12025550102'}),
        ),
        isFalse,
      );
    },
  );
  test(
    'prices and first-minute thresholds use v65 models, not two minutes',
    () {
      for (final pair in <String?, int>{
        null: 100,
        'unknown': 100,
        'Doubao': 110,
        'SEEDUPLEX': 110,
        'doubao V3': 150,
        '3_0': 150,
        '3.0': 150,
      }.entries) {
        for (final count in [0, 1, 3]) {
          final total = pair.value * (count < 1 ? 1 : count);
          expect(
            CallAdmissionPolicy.evaluate(
              balance: total,
              model: pair.key,
              recipients: count,
              notified: false,
            ).kind,
            CallAdmissionKind.allow,
          );
          expect(
            CallAdmissionPolicy.evaluate(
              balance: total - 1,
              model: pair.key,
              recipients: count,
              notified: false,
            ).kind,
            CallAdmissionKind.firstInsufficient,
          );
        }
      }
      expect(
        CallAdmissionPolicy.evaluate(
          balance: null,
          model: 'V3',
          recipients: 3,
          notified: true,
        ).kind,
        CallAdmissionKind.allow,
      );
    },
  );
  test(
    'each confirmation refreshes; first insufficient is remembered and top-up allows',
    () async {
      final f = AdmissionFixture()
        ..balance = 50
        ..refreshed = 50;
      final first = await f.service.evaluate(
        callRequest(),
        priorRequests: [],
        isCurrent: () => true,
      );
      expect(first!.kind, CallAdmissionKind.firstInsufficient);
      expect(first.firstNotice, '积分不足，无法发起本次通话。请补充积分后再试。');
      expect(f.refreshes, 1);
      f.refreshed = 100;
      final next = await f.service.evaluate(
        callRequest(),
        priorRequests: [],
        isCurrent: () => true,
      );
      expect(next!.kind, CallAdmissionKind.allow);
      expect(f.refreshes, 2);
      expect(f.commits, 0);
    },
  );
  test(
    'history same-task aliases detect repeats with new tool and ordinal',
    () async {
      final f = AdmissionFixture()
        ..balance = 0
        ..refreshed = 0;
      final previous = callRequest();
      await f.markNotified(previous.sessionId, previous.aliases);
      final next = await f.service.evaluate(
        callRequest(tool: 'new', ordinal: 2),
        priorRequests: [previous],
        isCurrent: () => true,
      );
      expect(next!.kind, CallAdmissionKind.repeatedInsufficient);
      expect(f.refreshes, 1);
    },
  );
  test(
    'unknown refreshed balance delegates atomic check; account errors throw',
    () async {
      final f = AdmissionFixture()
        ..balance = 0
        ..refreshed = null;
      await f.markNotified('session', callRequest().aliases);
      expect(
        (await f.service.evaluate(
          callRequest(),
          priorRequests: [],
          isCurrent: () => true,
        ))!.kind,
        CallAdmissionKind.allow,
      );
      f.onRefresh = () async => throw StateError('account changed');
      await expectLater(
        f.service.evaluate(
          callRequest(),
          priorRequests: [],
          isCurrent: () => true,
        ),
        throwsStateError,
      );
    },
  );
  test(
    'storage errors never allow known insufficient; notice is best effort',
    () async {
      final f = AdmissionFixture()
        ..balance = 0
        ..refreshed = 0
        ..readFails = true
        ..writeFails = true;
      final result = await f.service.evaluate(
        callRequest(),
        priorRequests: [],
        isCurrent: () => true,
      );
      expect(result!.kind, CallAdmissionKind.firstInsufficient);
      expect(result.persistenceFailed, isTrue);
      expect(
        await f.service.record(callRequest(), isCurrent: () => true),
        isFalse,
      );
      expect(f.commits, 1);
    },
  );
  test(
    'idempotent notice retries at most three times, 300ms between attempts',
    () async {
      final f = AdmissionFixture()..retries = 2;
      expect(
        await f.service.record(callRequest(), isCurrent: () => true),
        isTrue,
      );
      expect(f.commits, 3);
      expect(f.waits, [
        const Duration(milliseconds: 300),
        const Duration(milliseconds: 300),
      ]);
      final fail = AdmissionFixture()..retries = 5;
      expect(
        await fail.service.record(callRequest(), isCurrent: () => true),
        isFalse,
      );
      expect(fail.commits, 3);
    },
  );
  test('terminal error and cancelled retry never repost notices', () async {
    final f = AdmissionFixture()..failure = CallAdmissionNoticeFailure.terminal;
    expect(
      await f.service.record(callRequest(), isCurrent: () => true),
      isFalse,
    );
    expect(f.commits, 1);
    var current = true;
    final cancelled = AdmissionFixture()
      ..retries = 5
      ..onWait = (_) async {
        current = false;
      };
    expect(
      await cancelled.service.record(callRequest(), isCurrent: () => current),
      isFalse,
    );
    expect(cancelled.commits, 1);
  });
  test(
    'already cancelled request cannot read, refresh, save or post',
    () async {
      final f = AdmissionFixture()..readFails = true;
      expect(
        await f.service.evaluate(
          callRequest(),
          priorRequests: [],
          isCurrent: () => false,
        ),
        isNull,
      );
      expect(
        await f.service.record(callRequest(), isCurrent: () => false),
        isFalse,
      );
      expect(f.commits, 0);
      expect(f.keys, isEmpty);
    },
  );
}
