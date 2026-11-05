import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/account_cancellation/domain/account_cancellation.dart';
import 'package:phone_agent/features/account_cancellation/presentation/cancellation_coordinator.dart';
import '../../support/cancellation_scenario.dart';

class _InactiveGateway extends CancellationScenario {
  @override
  Future<CancellationConfirmation> confirmation() async =>
      throw CancellationFailure.accountChanged;
}

class _SlowGateway extends CancellationScenario {
  final pending = Completer<CancellationConfirmation>();
  @override
  Future<CancellationConfirmation> confirmation() => pending.future;
}

void main() {
  test(
    'preparation asks server for current confirmation without old lookup',
    () async {
      final gateway = CancellationScenario()..failQuery = true;
      final coordinator = CancellationCoordinator(gateway);
      expect(await coordinator.prepare(), same(gateway.confirmationData));
      expect(gateway.confirmations, 1);
      expect(gateway.queries, 0);
      expect(gateway.sends, 0);
      expect(gateway.submissions, 0);
    },
  );

  test('server account refusal still prevents a new operation', () async {
    final gateway = _InactiveGateway();
    await expectLater(
      CancellationCoordinator(gateway).prepare(),
      throwsA(CancellationFailure.accountChanged),
    );
    expect(gateway.queries, 0);
    expect(gateway.sends, 0);
    expect(gateway.submissions, 0);
  });

  test('late confirmation cannot continue for a replacement account', () async {
    final gateway = _SlowGateway();
    var current = true;
    final result = CancellationCoordinator(
      gateway,
    ).prepare(isCurrent: () => current);
    final expectation = expectLater(
      result,
      throwsA(CancellationFailure.accountChanged),
    );
    current = false;
    gateway.pending.complete(gateway.confirmationData);
    await expectation;
    expect(gateway.sends, 0);
  });

  test('new page operation never restores a disposed operation', () async {
    final gateway = CancellationScenario()
      ..loseResponse = true
      ..failQuery = true;
    final coordinator = CancellationCoordinator(gateway);
    final first = coordinator.begin(
      await coordinator.prepare(),
      isCurrent: () => true,
    );
    await first.send();
    await first.verify('123456');
    await first.submit();
    expect(first.snapshot.unknown, isTrue);
    expect(gateway.queries, 1);
    final oldId = first.operationId;
    first.dispose();
    final next = coordinator.begin(
      await coordinator.prepare(),
      isCurrent: () => true,
    );
    addTearDown(next.dispose);
    expect(next.operationId, isNot(oldId));
    expect(next.snapshot.unknown, isFalse);
    expect(next.snapshot.delivery, isNull);
    expect(next.snapshot.result, isNull);
    expect(gateway.confirmations, 2);
    expect(gateway.queries, 1);
    expect(gateway.submissions, 1);
  });
}
