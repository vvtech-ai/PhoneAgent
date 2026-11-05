import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/translation/domain/translation_backend_session.dart';
import 'package:phone_agent/features/translation/domain/translation_service_catalog.dart';
import 'package:phone_agent/features/translation/domain/translation_session_coordinator.dart';
import '../../support/translation_session_fixture.dart';

Future<void> flush() => Future<void>.delayed(Duration.zero);
void main() {
  test(
    'catalog/create/ready/merchant order, duplicate start and stop single-flight',
    () async {
      final f = SessionFixture();
      await Future.wait([
        f.coordinator.start(translationRequest),
        f.coordinator.start(translationRequest),
      ]);
      expect(f.events, ['languages', 'create', 'connect:live', 'merchant']);
      expect(f.backend.received!.userLanguage, 'zh-CN');
      expect(f.backend.received!.merchantLanguage, 'en-US');
      expect(f.coordinator.stage, TranslationSessionStage.ringing);
      await Future.wait([f.coordinator.stop(), f.coordinator.stop()]);
      expect(f.events, [
        'languages',
        'create',
        'connect:live',
        'merchant',
        'close:live',
        'hangup',
      ]);
    },
  );
  test('unsupported language fails before any create', () async {
    final f = SessionFixture()..catalog = const TranslationServiceCatalog([]);
    await f.coordinator.start(translationRequest);
    expect(f.events, ['languages']);
    expect(f.coordinator.stage, TranslationSessionStage.failed);
  });
  test(
    'repository cleanup uncertainty survives into terminal status',
    () async {
      final f = SessionFixture();
      f.backend.createFailure = const TranslationBackendFailure(
        'INVALID_RESPONSE_CLEANUP_FAILED',
      );
      await f.coordinator.start(translationRequest);
      expect(f.errors.last, '通话未接通，请稍后重试');
      expect(f.coordinator.cleanupUnconfirmed, true);
      await f.coordinator.stop();
      expect(f.coordinator.stage, TranslationSessionStage.failed);
      expect(f.events, ['languages', 'create']);
    },
  );
  test(
    'LiveKit failure closes it before websocket fallback and dialing',
    () async {
      final f = SessionFixture();
      f.live.fail = true;
      await f.coordinator.start(translationRequest);
      expect(f.events, [
        'languages',
        'create',
        'connect:live',
        'close:live',
        'connect:ws',
        'merchant',
      ]);
      await f.coordinator.stop();
    },
  );
  test(
    'both media paths failing never dial and release created session',
    () async {
      final f = SessionFixture();
      f.live.fail = true;
      f.ws.fail = true;
      await f.coordinator.start(translationRequest);
      expect(f.events, [
        'languages',
        'create',
        'connect:live',
        'close:live',
        'connect:ws',
        'close:ws',
        'hangup',
      ]);
      expect(f.coordinator.stage, TranslationSessionStage.failed);
    },
  );
  test('cancel before asynchronous start performs no IO', () async {
    final f = SessionFixture();
    final start = f.coordinator.start(translationRequest);
    await f.coordinator.stop();
    await start;
    expect(f.events, isEmpty);
  });
  test('cancel during language query prevents create', () async {
    final f = SessionFixture()
      ..catalogGate = Completer<TranslationServiceCatalog>();
    final start = f.coordinator.start(translationRequest);
    await flush();
    final stop = f.coordinator.stop();
    f.catalogGate!.complete(f.catalog);
    await start;
    await stop;
    expect(f.events, ['languages']);
  });
  test(
    'cancel during create reclaims late ticket without media or merchant',
    () async {
      final f = SessionFixture();
      f.backend.createGate = Completer<TranslationBackendSession>();
      final start = f.coordinator.start(translationRequest);
      await flush();
      final stop = f.coordinator.stop();
      f.backend.createGate!.complete(translationTicket);
      await start;
      await stop;
      expect(f.events, ['languages', 'create', 'hangup']);
    },
  );
  test(
    'cancel during media ready suppresses call and closes exactly once',
    () async {
      final f = SessionFixture();
      f.live.gate = Completer<void>();
      final start = f.coordinator.start(translationRequest);
      await flush();
      final stop = f.coordinator.stop();
      f.live.gate!.complete();
      await start;
      await stop;
      expect(f.events, [
        'languages',
        'create',
        'connect:live',
        'close:live',
        'hangup',
      ]);
    },
  );
  test(
    'hangup waits for in-flight merchant response, never rings after cancel',
    () async {
      final f = SessionFixture();
      f.backend.merchantGate = Completer<TranslationMerchantResult>();
      final start = f.coordinator.start(translationRequest);
      await flush();
      final stop = f.coordinator.stop();
      await flush();
      expect(f.events.last, 'close:live');
      expect(f.events, isNot(contains('hangup')));
      f.backend.merchantGate!.complete(const TranslationMerchantResult(true));
      await start;
      await stop;
      expect(f.events.last, 'hangup');
      expect(f.stages, isNot(contains(TranslationSessionStage.ringing)));
    },
  );
  test(
    'only explicit media 409 retries, bounded even with unchanged clock',
    () async {
      final f = SessionFixture();
      f.backend.failures.addAll(
        List.filled(
          25,
          const TranslationBackendFailure(
            'MEDIA_CHANNEL_NOT_READY',
            status: 409,
          ),
        ),
      );
      await f.coordinator.start(translationRequest);
      expect(f.events.where((e) => e == 'merchant'), hasLength(21));
      expect(f.events.where((e) => e == 'wait'), hasLength(20));
      expect(f.events.last, 'hangup');
    },
  );
  test('network unknown is never retried', () async {
    final f = SessionFixture();
    f.backend.failures.add(const TranslationBackendFailure('NETWORK'));
    await f.coordinator.start(translationRequest);
    expect(f.events.where((e) => e == 'merchant'), hasLength(1));
    expect(f.events, isNot(contains('wait')));
  });
  test('media timeout closes old transport before fallback', () async {
    final f = SessionFixture()..readyTimeout = Duration.zero;
    f.live.gate = Completer<void>();
    await f.coordinator.start(translationRequest);
    expect(f.events, [
      'languages',
      'create',
      'connect:live',
      'close:live',
      'connect:ws',
      'merchant',
    ]);
    f.live.gate!.complete();
    await flush();
    expect(f.events.where((e) => e == 'merchant'), hasLength(1));
    await f.coordinator.stop();
  });
  test('reentrant cancel at creating prevents request', () async {
    final f = SessionFixture();
    Future<void>? stop;
    f.onStage = (stage) {
      if (stage == TranslationSessionStage.creating) {
        stop = f.coordinator.stop();
      }
    };
    await f.coordinator.start(translationRequest);
    await stop;
    expect(f.events, ['languages']);
    expect(f.coordinator.stage, TranslationSessionStage.ended);
  });
  test('explicit media-not-ready can recover without recreating', () async {
    final f = SessionFixture();
    f.backend.failures.add(
      const TranslationBackendFailure('media_channel_not_ready', status: 409),
    );
    await f.coordinator.start(translationRequest);
    expect(f.events.where((e) => e == 'create'), hasLength(1));
    expect(f.events.where((e) => e == 'merchant'), hasLength(2));
    expect(f.events.where((e) => e == 'wait'), hasLength(1));
    expect(f.coordinator.stage, TranslationSessionStage.ringing);
    await f.coordinator.stop();
  });
  test(
    'not-started and cleanup failure remain failure, not connected',
    () async {
      final f = SessionFixture();
      f.backend.started = false;
      f.backend.hangupFails = true;
      await f.coordinator.start(translationRequest);
      expect(f.coordinator.stage, TranslationSessionStage.failed);
      expect(f.errors.last, '通话未接通，请稍后重试');
      expect(f.coordinator.cleanupUnconfirmed, true);
    },
  );
  test(
    'dispose silences late notifications but still releases known session',
    () async {
      final f = SessionFixture();
      f.backend.createGate = Completer<TranslationBackendSession>();
      final start = f.coordinator.start(translationRequest);
      await flush();
      final count = f.stages.length;
      final closed = f.coordinator.dispose();
      f.backend.createGate!.complete(translationTicket);
      await start;
      await closed;
      expect(f.stages, hasLength(count));
      expect(f.events.last, 'hangup');
    },
  );
}
