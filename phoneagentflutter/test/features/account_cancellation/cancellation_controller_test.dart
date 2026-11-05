import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/account_cancellation/presentation/cancellation_controller.dart';
import 'package:phone_agent/features/account_cancellation/domain/account_cancellation.dart';
import '../../support/cancellation_scenario.dart';

void main() {
  test(
    'creation does not send; cooldown and six-digit gate remain independent',
    () async {
      final gateway = CancellationScenario();
      var now = DateTime.utc(2026, 10, 26);
      final controller = CancellationController(
        gateway,
        gateway.confirmationData,
        isCurrent: () => true,
        now: () => now,
      );
      addTearDown(controller.dispose);
      expect(gateway.sends, 0);
      await controller.send();
      await controller.send();
      expect(gateway.sends, 1);
      await controller.verify('12345');
      await controller.submit();
      expect(gateway.submissions, 0);
      now = now.add(const Duration(seconds: 61));
      controller.refreshCooldown();
      await controller.send();
      expect(gateway.sends, 2);
      await controller.verify('123456');
      await controller.submit();
      await controller.verify('123456');
      await controller.submit();
      expect(gateway.submissions, 1);
    },
  );
  test(
    'lost response queries original operation and accepts only confirmed result',
    () async {
      final gateway = CancellationScenario()..loseResponse = true;
      final controller = CancellationController(
        gateway,
        gateway.confirmationData,
        isCurrent: () => true,
      );
      addTearDown(controller.dispose);
      await controller.send();
      final operation = controller.operationId;
      await controller.verify('123456');
      await controller.submit();
      expect(gateway.submissions, 1);
      expect(gateway.queries, 1);
      expect(controller.snapshot.result?.accepted, true);
      expect(controller.operationId, operation);
    },
  );
  test(
    'unknown result retries only lookup; failure is not accepted or new submission',
    () async {
      final gateway = CancellationScenario()
        ..loseResponse = true
        ..failQuery = true;
      final controller = CancellationController(
        gateway,
        gateway.confirmationData,
        isCurrent: () => true,
      );
      addTearDown(controller.dispose);
      await controller.send();
      await controller.verify('123456');
      await controller.submit();
      expect(controller.snapshot.unknown, true);
      expect(controller.snapshot.result, isNull);
      controller.discardVerification();
      expect(controller.snapshot.verification, isNotNull);
      await controller.send();
      await controller.verify('123456');
      await controller.submit();
      expect(gateway.submissions, 1);
      expect(gateway.sends, 1);
      expect(gateway.queries, 2);
      gateway.failQuery = false;
      await controller.recover();
      expect(controller.snapshot.result?.accepted, true);
    },
  );
  test(
    'definite not-submitted can retry; stale owner cannot send or apply',
    () async {
      final gateway = CancellationScenario()
        ..loseResponse = true
        ..notSubmitted = true;
      var current = true;
      final controller = CancellationController(
        gateway,
        gateway.confirmationData,
        isCurrent: () => current,
      );
      addTearDown(controller.dispose);
      await controller.send();
      await controller.verify('123456');
      await controller.submit();
      expect(controller.snapshot.unknown, false);
      expect(controller.snapshot.result, isNull);
      current = false;
      await controller.verify('123456');
      await controller.submit();
      expect(gateway.submissions, 1);
    },
  );
  test(
    'verification alone never submits an application; resending resets proof',
    () async {
      final gateway = CancellationScenario();
      var now = DateTime.utc(2026);
      final controller = CancellationController(
        gateway,
        gateway.confirmationData,
        isCurrent: () => true,
        now: () => now,
      );
      addTearDown(controller.dispose);
      await controller.send();
      await controller.submit();
      expect(gateway.submissions, 0);
      await controller.verify('123456');
      expect(gateway.verifications, 1);
      expect(controller.snapshot.verification, isNotNull);
      expect(gateway.submissions, 0);
      expect(controller.snapshot.result, isNull);
      controller.discardVerification();
      expect(controller.snapshot.verification, isNull);
      await controller.submit();
      expect(gateway.submissions, 0);
      await controller.verify('123456');
      expect(gateway.verifications, 2);
      now = now.add(const Duration(seconds: 61));
      controller.refreshCooldown();
      await controller.send();
      expect(controller.snapshot.verification, isNull);
      await controller.submit();
      expect(gateway.submissions, 0);
    },
  );
  test('late verification is ignored after owner changes', () async {
    final gateway = _DelayedVerification();
    var current = true;
    final controller = CancellationController(
      gateway,
      gateway.confirmationData,
      isCurrent: () => current,
    );
    addTearDown(controller.dispose);
    await controller.send();
    final work = controller.verify('123456');
    current = false;
    gateway.done.complete(
      CancellationVerification(
        'synthetic',
        DateTime.utc(2099),
        gateway.confirmationData,
      ),
    );
    await work;
    expect(controller.snapshot.verification, isNull);
    expect(gateway.submissions, 0);
  });
  for (final unknown in [false, true]) {
    test(
      'expired proof ${unknown ? 'retains unknown result' : 'returns to verification'} without another submission',
      () async {
        final gateway = _ExpiredSubmission()
          ..notSubmitted = true
          ..failQuery = unknown;
        final controller = CancellationController(
          gateway,
          gateway.confirmationData,
          isCurrent: () => true,
        );
        addTearDown(controller.dispose);
        await controller.send();
        await controller.verify('123456');
        await controller.submit();
        expect(gateway.submissions, 1);
        expect(gateway.queries, 1);
        expect(controller.snapshot.result, isNull);
        expect(controller.snapshot.unknown, unknown);
        if (unknown) {
          await controller.submit();
          expect(gateway.submissions, 1);
          expect(gateway.queries, 2);
          gateway.failQuery = false;
          await controller.recover();
          expect(controller.snapshot.verification, isNull);
        } else {
          expect(
            controller.snapshot.notice,
            CancellationFailure.verificationExpired.message,
          );
          expect(controller.snapshot.verification, isNull);
          await controller.submit();
          expect(gateway.submissions, 1);
        }
      },
    );
  }
  test('late owner response is ignored', () async {
    final gateway = _Delayed();
    var current = true;
    final controller = CancellationController(
      gateway,
      gateway.confirmationData,
      isCurrent: () => current,
    );
    addTearDown(controller.dispose);
    final send = controller.send();
    current = false;
    gateway.done.complete(
      const CancellationDelivery('c', 'q', '138****0000', 60),
    );
    await send;
    expect(controller.snapshot.delivery, isNull);
  });
  test('Beijing date does not depend on local timezone', () {
    expect(
      cancellationTime(DateTime.utc(2026, 10, 26, 17, 2)),
      '2026年10月27日 01:02（北京时间）',
    );
  });
}

class _Delayed extends CancellationScenario {
  final done = Completer<CancellationDelivery>();
  @override
  Future<CancellationDelivery> send(
    CancellationConfirmation c,
    String operation,
  ) => done.future;
}

class _DelayedVerification extends CancellationScenario {
  final done = Completer<CancellationVerification>();
  @override
  Future<CancellationVerification> verify(
    CancellationDelivery d,
    String operation,
    String code,
  ) => done.future;
}

class _ExpiredSubmission extends CancellationScenario {
  @override
  Future<CancellationResult> submit(
    CancellationDelivery d,
    String operation,
    String proof,
  ) async {
    submissions++;
    throw CancellationFailure.verificationExpired;
  }
}
