import 'package:flutter_test/flutter_test.dart';
import 'dart:async';
import 'package:phone_agent/features/translation/domain/translation_call_view.dart';
import 'package:phone_agent/features/translation/domain/sip/sip_transactions.dart';
import 'domestic_sip_test_harness.dart';

void main() {
  test(
    'iOS audio preparation failure must not report billing connected',
    () async {
      final h = DomesticSipTestHarness(prepareMediaBeforeConnected: true)
        ..media.failPrepare = true;
      await h.coordinator.start();
      expect(h.trace, isNot(contains('points.connected')));
      expect(h.trace, contains('points.terminal'));
      expect(h.media.closed, isTrue);
      expect(h.points.events.last.connected, false);
      expect(h.points.events.last.durationMs, 0);
    },
  );

  test('iOS prepares before connected and starts media only once', () async {
    final h = DomesticSipTestHarness(prepareMediaBeforeConnected: true);
    await h.coordinator.start();
    h.connection.phase!(SipCallPhase.connected);
    await h.coordinator.start();
    expect(
      h.trace.indexOf('media.prepare'),
      lessThan(h.trace.indexOf('points.connected')),
    );
    expect(
      h.trace.indexOf('points.connected'),
      lessThan(h.trace.indexOf('media.start')),
    );
    expect(h.trace.where((v) => v == 'points.connected'), hasLength(1));
    expect(
      h.phases.where((v) => v == TranslationPhase.connected),
      hasLength(1),
    );
    await h.coordinator.close();
  });

  for (final remoteEnd in [false, true]) {
    test(
      'iOS late preparation cannot bill after ${remoteEnd ? 'remote end' : 'hangup'}',
      () async {
        final h = DomesticSipTestHarness(prepareMediaBeforeConnected: true)
          ..media.pendingPrepare = Completer<void>();
        final start = h.coordinator.start();
        await Future<void>.delayed(Duration.zero);
        expect(h.trace, contains('media.prepare'));
        expect(h.phases, isNot(contains(TranslationPhase.connected)));
        if (remoteEnd) {
          h.connection.ended.complete();
          await Future<void>.delayed(Duration.zero);
        }
        await h.coordinator.close();
        h.media.pendingPrepare!.complete();
        await start;
        expect(h.trace, isNot(contains('points.connected')));
        expect(h.trace, isNot(contains('media.start')));
        expect(h.trace.where((v) => v == 'points.terminal'), hasLength(1));
      },
    );
  }

  test(
    'Android default retains connected before media even on media failure',
    () async {
      final h = DomesticSipTestHarness()..media.failStart = true;
      await h.coordinator.start();
      expect(
        h.trace.indexOf('points.connected'),
        lessThan(h.trace.indexOf('media.start')),
      );
      expect(h.trace, isNot(contains('media.prepare')));
      expect(h.trace, contains('points.terminal'));
    },
  );

  test('iOS account invalidation during preparation cannot connect', () async {
    final h = DomesticSipTestHarness(prepareMediaBeforeConnected: true)
      ..media.pendingPrepare = Completer<void>();
    final start = h.coordinator.start();
    await Future<void>.delayed(Duration.zero);
    h.current = false;
    h.media.pendingPrepare!.complete();
    await start;
    expect(h.trace, isNot(contains('points.connected')));
    expect(h.trace, isNot(contains('media.start')));
    expect(h.media.closed, true);
  });

  test(
    'iOS connected reporting failure closes prepared media without running it',
    () async {
      final h = DomesticSipTestHarness(prepareMediaBeforeConnected: true)
        ..points.failConnected = true;
      await h.coordinator.start();
      await h.coordinator.close();
      expect(h.trace, contains('media.prepare'));
      expect(h.trace, contains('points.connected'));
      expect(h.trace, isNot(contains('media.start')));
      expect(h.media.closed, true);
    },
  );
}
