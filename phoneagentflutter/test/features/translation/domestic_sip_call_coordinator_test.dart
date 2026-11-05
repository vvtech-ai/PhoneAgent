import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/translation/domain/translation_call_environment.dart';
import 'package:phone_agent/features/translation/domain/translation_call_view.dart';
import 'package:phone_agent/features/translation/domain/sip/domestic_sip_media.dart';
import 'package:phone_agent/features/translation/domain/sip/sip_lease.dart';
import 'package:phone_agent/features/translation/domain/sip/domestic_translation_model.dart';
import 'domestic_sip_test_harness.dart';

void main() {
  test(
    'domestic media starts with loudspeaker and preserves pre-connect toggle',
    () async {
      final standard = DomesticSipTestHarness();
      await standard.coordinator.start();
      expect(standard.media.speaker, true);
      expect(standard.media.speakerAtStart, true);
      await standard.coordinator.close();
      final quiet = DomesticSipTestHarness()
        ..pendingMedia = Completer<DomesticSipMedia>();
      final start = quiet.coordinator.start();
      await Future<void>.delayed(Duration.zero);
      await quiet.coordinator.setSpeaker(false);
      quiet.pendingMedia!.complete(quiet.media);
      await start;
      expect(quiet.media.speaker, false);
      expect(quiet.media.speakerAtStart, false);
      await quiet.coordinator.close();
    },
  );
  test(
    'actual model handshake and SIP registration update all three indicators',
    () async {
      final h = DomesticSipTestHarness();
      await h.coordinator.start();
      expect(
        h.environments.last.network,
        TranslationEnvironmentState.available,
      );
      expect(h.environments.last.sip, TranslationEnvironmentState.available);
      expect(h.environments.last.model, TranslationEnvironmentState.available);
      await h.coordinator.close();
      final count = h.environments.length;
      await h.coordinator.close();
      expect(h.environments.length, count);
    },
  );
  test('model configuration failure marks model only', () async {
    final h = DomesticSipTestHarness()..source.available = false;
    await h.coordinator.start();
    expect(h.environments.last.model, TranslationEnvironmentState.unavailable);
    expect(h.environments.last.sip, TranslationEnvironmentState.pending);
    await h.coordinator.close();
  });
  test('SIP start failure keeps confirmed model available', () async {
    final h = DomesticSipTestHarness()..connection.failStart = true;
    await h.coordinator.start();
    expect(h.environments.last.sip, TranslationEnvironmentState.unavailable);
    expect(h.environments.last.model, TranslationEnvironmentState.available);
    await h.coordinator.close();
  });
  test(
    'diagnostics retain connected failure and do not alter cleanup',
    () async {
      final h = DomesticSipTestHarness();
      await h.coordinator.start();
      expect(h.diagnostics, contains('pointsConnected:succeeded:'));
      expect(h.diagnostics, contains('media:succeeded:'));
      await h.coordinator.close();
      expect(h.diagnostics, contains('terminal:succeeded:'));
      final broken = DomesticSipTestHarness()..source.available = false;
      await broken.coordinator.start();
      expect(
        broken.diagnostics,
        contains('terminal:failed:MODEL_CONFIGURATION_UNAVAILABLE'),
      );
    },
  );
  test('prepare admits once without model, lease, SIP or media', () async {
    final h = DomesticSipTestHarness();
    await h.coordinator.prepare();
    await h.coordinator.prepare();
    expect(h.trace, ['config', 'points.create']);
    expect(h.phases, isEmpty);
    await h.coordinator.start();
    expect(h.trace.where((e) => e == 'config').length, 1);
    expect(h.trace.where((e) => e == 'points.create').length, 1);
    expect(h.trace.where((e) => e == 'sip.start').length, 1);
    await h.coordinator.close();
  });
  test('prepared cancellation releases points without connecting', () async {
    final h = DomesticSipTestHarness();
    await h.coordinator.prepare();
    await h.coordinator.close();
    await h.coordinator.start();
    expect(h.trace, ['config', 'points.create', 'points.terminal']);
    expect(h.coordinator.connected, isFalse);
  });

  test(
    'cancel during asynchronous media allocation reaps late media without starting it',
    () async {
      final h = DomesticSipTestHarness();
      h.pendingMedia = Completer<DomesticSipMedia>();
      final start = h.coordinator.start();
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await h.coordinator.close();
      await start;
      h.pendingMedia!.complete(h.media);
      await Future<void>.delayed(Duration.zero);
      expect(h.media.closed, true);
      expect(h.trace, isNot(contains('media.start')));
      expect(h.trace.where((v) => v == 'points.terminal').length, 1);
    },
  );
  test(
    'missing model config refuses before points or SIP allocation',
    () async {
      final h = DomesticSipTestHarness()..source.available = false;
      await h.coordinator.start();
      expect(h.trace, ['config']);
      expect(h.phases.last, TranslationPhase.failed);
      expect(h.errors.last, 'MODEL_CONFIGURATION_UNAVAILABLE');
    },
  );
  test(
    'config→points→two model ready→lease→SIP→media; close settles once',
    () async {
      final h = DomesticSipTestHarness();
      await h.coordinator.start();
      expect(h.trace, [
        'config',
        'points.create',
        'model.start',
        'model.start',
        'lease.acquire',
        'sip.open',
        'sip.start',
        'points.connected',
        'media.start',
      ]);
      expect(h.phases.last, TranslationPhase.translating);
      expect(h.connectionLease?.accountId, 'synthetic-account');
      h.coordinator.setMuted(true);
      await h.coordinator.setSpeaker(true);
      await h.coordinator.sendDtmf('1');
      expect(h.media.muted, true);
      expect(h.media.speaker, true);
      expect(h.media.digits, ['1']);
      await h.coordinator.close();
      await h.coordinator.close();
      expect(h.trace.where((entry) => entry == 'lease.release').length, 1);
      expect(h.trace.where((entry) => entry == 'points.terminal').length, 1);
      expect(
        h.trace.indexOf('media.close'),
        lessThan(h.trace.indexOf('lease.release')),
      );
      expect(h.phases.last, TranslationPhase.ended);
      expect(h.stoppedDurations.length, 1);
    },
  );
  test(
    'cancelled config load completes promptly without financial requests',
    () async {
      final h = DomesticSipTestHarness();
      h.source.pending = Completer<DomesticModelConfiguration?>();
      final start = h.coordinator.start();
      await Future<void>.delayed(Duration.zero);
      await h.coordinator.close();
      await start;
      h.source.pending!.complete(h.source.config);
      await Future<void>.delayed(Duration.zero);
      expect(h.trace, ['config']);
    },
  );
  test(
    'cancelled late SIP lease only releases and never opens connection',
    () async {
      final h = DomesticSipTestHarness();
      h.leases.pending = Completer<SipLease>();
      final start = h.coordinator.start();
      await Future<void>.delayed(Duration.zero);
      final closed = h.coordinator.close();
      h.leases.pending!.complete(syntheticDomesticLease);
      await start;
      await closed;
      expect(h.trace, isNot(contains('sip.open')));
      expect(h.trace.where((entry) => entry == 'lease.release').length, 1);
      expect(h.trace.last, 'points.terminal');
    },
  );
  test('busy code survives a simultaneous settlement failure', () async {
    final h = DomesticSipTestHarness();
    h.connection.failStart = true;
    h.connection.failureCode = 'INVITE_486';
    h.points.failTerminal = true;
    await h.coordinator.start();
    expect(h.errors.last, 'INVITE_486');
    expect(h.coordinator.cleanupUnconfirmed, true);
    expect(h.phases.last, TranslationPhase.failed);
    expect(h.diagnostics, contains('terminal:failed:CALL_CLEANUP_UNCONFIRMED'));
  });
  test(
    'remote end clears media and leases and failed settlement stays unconfirmed',
    () async {
      final h = DomesticSipTestHarness();
      h.points.failTerminal = true;
      await h.coordinator.start();
      h.connection.ended.complete();
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await h.coordinator.close();
      expect(h.media.closed, true);
      expect(h.coordinator.cleanupUnconfirmed, true);
      expect(h.errors.last, 'POINTS_SETTLEMENT_UNCONFIRMED');
      expect(h.phases.last, TranslationPhase.failed);
      expect(h.trace.where((entry) => entry == 'sip.start').length, 1);
    },
  );
}
