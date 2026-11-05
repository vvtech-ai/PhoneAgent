import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/translation/domain/translation_call_view.dart';
import 'domestic_sip_test_harness.dart';

void main() {
  for (final throws in [true, false]) {
    test(
      'settlement unconfirmed after hangup: request throws=$throws',
      () async {
        final h = DomesticSipTestHarness();
        h.points.failTerminal = throws;
        h.points.unconfirmedTerminal = !throws;
        await h.coordinator.start();
        await h.coordinator.close();
        await h.coordinator.close();
        expect(h.errors.last, 'POINTS_SETTLEMENT_UNCONFIRMED');
        expect(h.phases.last, TranslationPhase.failed);
        expect(h.coordinator.billing.settlementUnconfirmed, isTrue);
        expect(h.coordinator.cleanupUnconfirmed, isTrue);
        expect(h.coordinator.billing.session?.settled, isFalse);
        expect(h.media.closed, isTrue);
        expect(h.trace.where((e) => e == 'points.terminal'), hasLength(1));
        expect(h.trace.where((e) => e == 'lease.release'), hasLength(1));
      },
    );
  }
  for (final code in ['INVITE_486', 'SIP_NETWORK_UNAVAILABLE']) {
    test('primary error $code survives settlement failure', () async {
      final h = DomesticSipTestHarness();
      h.connection.failStart = true;
      h.connection.failureCode = code;
      h.points.failTerminal = true;
      await h.coordinator.start();
      expect(h.errors.last, code);
      expect(h.coordinator.billing.settlementUnconfirmed, isTrue);
    });
  }
  test(
    'lease cleanup failure retains generic reason after confirmed settlement',
    () async {
      final h = DomesticSipTestHarness()..leases.failRelease = true;
      await h.coordinator.start();
      await h.coordinator.close();
      expect(h.errors.last, 'CALL_CLEANUP_UNCONFIRMED');
      expect(h.coordinator.billing.settlementUnconfirmed, isFalse);
      expect(h.coordinator.billing.session?.settled, isTrue);
      expect(h.coordinator.cleanupUnconfirmed, isTrue);
    },
  );
  test(
    'settled callback failure does not falsely report unconfirmed billing',
    () async {
      final h = DomesticSipTestHarness(
        onSettled: (_) => throw StateError('synthetic presentation failure'),
      );
      await h.coordinator.start();
      await h.coordinator.close();
      expect(h.errors.last, 'CALL_CLEANUP_UNCONFIRMED');
      expect(h.coordinator.billing.settlementUnconfirmed, isFalse);
      expect(h.coordinator.billing.session?.settled, isTrue);
    },
  );
  test('successful settlement keeps normal terminal without error', () async {
    final h = DomesticSipTestHarness();
    await h.coordinator.start();
    await h.coordinator.close();
    expect(h.errors.last, isEmpty);
    expect(h.phases.last, TranslationPhase.ended);
    expect(h.coordinator.cleanupUnconfirmed, isFalse);
    expect(h.coordinator.billing.settlementUnconfirmed, isFalse);
  });
}
