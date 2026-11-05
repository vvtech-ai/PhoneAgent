import 'package:phone_agent/features/translation/domain/translation_archive.dart';
import 'package:phone_agent/features/translation/domain/translation_session_coordinator.dart';
import 'dart:async';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/translation/domain/translation_backend_session.dart';
import 'package:phone_agent/features/translation/domain/translation_call_view.dart';
import '../../support/translation_interactive_fixture.dart';

Future<void> flush() => Future<void>.delayed(Duration.zero);
void main() {
  test(
    'direct translating starts once and rounds up final display',
    () => fakeAsync((clock) {
      final f = InteractiveSessionFixture();
      unawaited(f.controller.start());
      clock.flushMicrotasks();
      f.controller.coordinator.onStage(TranslationSessionStage.translating, '');
      f.now = f.now.add(const Duration(milliseconds: 1001));
      clock.elapse(const Duration(seconds: 1));
      expect(f.controller.snapshot.elapsedSeconds, 2);
      f.controller.coordinator.onStage(TranslationSessionStage.connected, '');
      unawaited(f.controller.hangup());
      clock.flushMicrotasks();
      expect(
        f.controller.finished!.connectedAtMillis,
        DateTime(2026).millisecondsSinceEpoch,
      );
      expect(f.controller.snapshot.elapsedSeconds, 2);
      unawaited(f.close());
      clock.flushMicrotasks();
      clock.elapse(const Duration(milliseconds: 501));
      clock.flushMicrotasks();
    }),
  );

  test(
    'terminal subtitle tail updates old archive after dispose, rejects new/wrong/expired segments',
    () => fakeAsync((clock) {
      final entries = <TranslationArchiveEntry>[];
      final f = InteractiveSessionFixture(onArchive: entries.add);
      unawaited(f.controller.start());
      clock.flushMicrotasks();
      f.live.wire('call_connected');
      void delta(String id, String text, {String session = 'session'}) =>
          f.live.wire(
            'transcript_delta',
            id: session,
            fields: {
              'segmentId': id,
              'sourceLeg': 'merchant',
              'kind': 'output',
              'text': text,
              'replace': true,
              'isFinal': true,
            },
          );
      delta('known', '初稿');
      unawaited(f.controller.hangup());
      clock.flushMicrotasks();
      f.controller.dispose();
      delta('known', '最终译文');
      delta('new', '不得新增');
      delta('known', '其他通话', session: 'other');
      expect(entries.last.transcripts.single.translated, '最终译文');
      expect(entries.last.transcripts.single.isFinal, true);
      f.now = f.now.add(const Duration(milliseconds: 501));
      clock.elapse(const Duration(milliseconds: 501));
      clock.flushMicrotasks();
      delta('known', '已超时');
      expect(entries.last.transcripts.single.translated, '最终译文');
      expect(f.trace.where((e) => e == 'hangup'), hasLength(1));
      unawaited(f.live.stream.close());
      unawaited(f.ws.stream.close());
      clock.flushMicrotasks();
      expect(clock.pendingTimers, isEmpty);
    }),
  );

  test('preflight controls queue and apply before merchant dialing', () async {
    final f = InteractiveSessionFixture();
    f.live.connectGate = Completer<void>();
    final start = f.controller.start();
    await flush();
    await f.controller.mute();
    await f.controller.speaker();
    f.controller.dialPad();
    expect(f.controller.snapshot.muted, true);
    expect(f.controller.snapshot.speaker, true);
    expect(f.controller.snapshot.dialPad, true);
    expect(f.trace, isNot(contains('merchant')));
    expect(f.trace, isNot(contains('mute:true')));
    f.live.connectGate!.complete();
    await start;
    expect(f.trace.indexOf('mute:true'), lessThan(f.trace.indexOf('merchant')));
    expect(
      f.trace.indexOf('speaker:true'),
      lessThan(f.trace.indexOf('merchant')),
    );
    await f.close();
  });
  test(
    'cancel during queued control application never dials or applies next control',
    () async {
      final f = InteractiveSessionFixture();
      f.live.connectGate = Completer<void>();
      f.live.controlGate = Completer<void>();
      final start = f.controller.start();
      await flush();
      await f.controller.mute();
      await f.controller.speaker();
      f.live.connectGate!.complete();
      await flush();
      expect(f.trace, contains('mute:true'));
      final stop = f.controller.hangup();
      await flush();
      f.live.controlGate!.complete();
      await start;
      await stop;
      expect(f.trace, isNot(contains('speaker:true')));
      expect(f.trace, isNot(contains('merchant')));
      await f.close();
    },
  );

  test(
    'started waits for actual connected event and ignores other session',
    () async {
      final f = InteractiveSessionFixture();
      await f.controller.start();
      expect(f.controller.snapshot.phase, TranslationPhase.ringing);
      f.live.wire('call_connected', id: 'other');
      expect(f.controller.snapshot.phase, TranslationPhase.ringing);
      f.live.wire('worker_ready');
      expect(f.controller.snapshot.phase, TranslationPhase.ringing);
      f.live.wire('call_connected', id: '');
      expect(f.controller.snapshot.phase, TranslationPhase.translating);
      await f.close();
    },
  );
  test(
    'connected before merchant response is not regressed to ringing',
    () async {
      final f = InteractiveSessionFixture();
      f.backend.merchantGate = Completer<TranslationMerchantResult>();
      final start = f.controller.start();
      await flush();
      f.live.wire('call_connected');
      expect(f.controller.snapshot.phase, TranslationPhase.translating);
      f.backend.merchantGate!.complete(const TranslationMerchantResult(true));
      await start;
      expect(f.controller.snapshot.phase, TranslationPhase.translating);
      await f.close();
    },
  );
  test(
    'user/blank merchant do not connect; merchant text does and merges output',
    () async {
      final f = InteractiveSessionFixture();
      await f.controller.start();
      void delta(String leg, String kind, String text) => f.live.wire(
        'transcript_delta',
        fields: {
          'segmentId': 's',
          'sourceLeg': leg,
          'kind': kind,
          'text': text,
          'isFinal': true,
        },
      );
      delta('user', 'input', '你好');
      delta('merchant', 'input', '');
      expect(f.controller.snapshot.phase, TranslationPhase.ringing);
      delta('merchant', 'input', 'Hello');
      delta('merchant', 'output', '你好');
      expect(f.controller.snapshot.phase, TranslationPhase.translating);
      expect(f.controller.snapshot.transcripts.last.primary, '你好');
      expect(f.controller.snapshot.transcripts, hasLength(2));
      await f.close();
    },
  );
  test(
    'early terminal waits in-flight merchant then cleanup exactly once',
    () async {
      final f = InteractiveSessionFixture();
      f.backend.merchantGate = Completer<TranslationMerchantResult>();
      final start = f.controller.start();
      await flush();
      f.live.wire('call_ended');
      expect(f.controller.snapshot.stopping, isTrue);
      await flush();
      expect(f.trace, isNot(contains('hangup')));
      f.live.wire('call_connected');
      f.backend.merchantGate!.complete(const TranslationMerchantResult(true));
      await start;
      await f.controller.coordinator.stop();
      expect(f.controller.snapshot.phase, TranslationPhase.ended);
      expect(f.trace.where((e) => e == 'hangup'), hasLength(1));
      expect(f.trace.where((e) => e == 'close:live'), hasLength(1));
      await f.close();
    },
  );
  test(
    'fallback unsubscribes old port and does not pretend AppAudio DTMF',
    () async {
      final f = InteractiveSessionFixture();
      f.live.failConnect = true;
      await f.controller.start();
      f.live.wire('call_connected');
      f.live.wire('call_ended');
      expect(f.controller.snapshot.phase, TranslationPhase.ringing);
      f.ws.wire('call_connected');
      f.controller.dialPad();
      await f.controller.digit('1');
      expect(f.controller.snapshot.dtmf, isEmpty);
      expect(f.controller.snapshot.error, contains('不支持'));
      expect(f.trace, isNot(contains('dtmf:1')));
      await f.close();
    },
  );
  for (final fault in ['error', 'done', 'protocol']) {
    test(
      '$fault stops active session, ignores late events and does not reconnect',
      () async {
        final f = InteractiveSessionFixture();
        await f.controller.start();
        if (fault == 'error') {
          f.live.stream.addError(StateError('private'));
        } else if (fault == 'done') {
          unawaited(f.live.stream.close());
        } else {
          f.live.wire('error');
        }
        await flush();
        await f.controller.coordinator.stop();
        expect(f.controller.snapshot.phase, TranslationPhase.failed);
        expect(f.controller.snapshot.error, isNot(contains('private')));
        expect(f.trace.where((e) => e.startsWith('connect:')), hasLength(1));
        await f.close();
      },
    );
  }
  test(
    'control accepted updates state; failure retains state and permits explicit retry',
    () async {
      final f = InteractiveSessionFixture();
      await f.controller.start();
      f.live.failControl = true;
      await f.controller.mute();
      await f.controller.speaker();
      expect(f.controller.snapshot.muted, isFalse);
      expect(f.controller.snapshot.speaker, isFalse);
      expect(f.controller.snapshot.error, contains('未成功'));
      f.live.failControl = false;
      await f.controller.mute();
      await f.controller.speaker();
      expect(f.controller.snapshot.muted, isTrue);
      expect(f.controller.snapshot.speaker, isTrue);
      f.controller.dialPad();
      await f.controller.digit('#');
      await f.controller.digit('bad');
      expect(f.controller.snapshot.dtmf, '#');
      expect(f.trace.where((e) => e.startsWith('dtmf:')), ['dtmf:#']);
      await f.close();
    },
  );
  test(
    'pending control single-flight, hangup is not blocked and late result ignored',
    () async {
      final f = InteractiveSessionFixture();
      await f.controller.start();
      f.live.controlGate = Completer<void>();
      final mute = f.controller.mute();
      await f.controller.mute();
      expect(f.controller.snapshot.controlsBusy, isTrue);
      await f.controller.hangup();
      f.live.controlGate!.complete();
      await mute;
      expect(f.controller.snapshot.phase, TranslationPhase.ended);
      expect(f.controller.snapshot.muted, isFalse);
      expect(f.trace.where((e) => e == 'mute:true'), hasLength(1));
      await f.close();
    },
  );
  test('cancel media preparation prevents merchant and future ready', () async {
    final f = InteractiveSessionFixture();
    f.live.connectGate = Completer<void>();
    final start = f.controller.start();
    await flush();
    await f.controller.hangup();
    await start;
    f.live.wire('call_connected');
    expect(f.trace, isNot(contains('merchant')));
    expect(f.controller.snapshot.phase, TranslationPhase.ended);
    await f.close();
  });
  test('hangup uncertainty is failure and never retried by dispose', () async {
    final f = InteractiveSessionFixture();
    f.backend.hangupFails = true;
    await f.controller.start();
    await f.controller.hangup();
    expect(f.controller.snapshot.phase, TranslationPhase.failed);
    expect(f.controller.snapshot.error, '通话未接通，请稍后重试');
    expect(f.controller.coordinator.cleanupUnconfirmed, true);
    await f.close();
    expect(f.trace.where((e) => e == 'hangup'), hasLength(1));
  });
  test(
    'timer begins only at connection, duplicate evidence does not reset; stops on end',
    () => fakeAsync((clock) {
      final f = InteractiveSessionFixture();
      unawaited(f.controller.start());
      clock.flushMicrotasks();
      f.now = f.now.add(const Duration(seconds: 10));
      clock.elapse(const Duration(seconds: 10));
      expect(f.controller.snapshot.elapsedSeconds, 0);
      f.live.wire('call_connected');
      f.now = f.now.add(const Duration(seconds: 3));
      clock.elapse(const Duration(seconds: 3));
      expect(f.controller.snapshot.elapsedSeconds, 3);
      f.live.wire('call_connected');
      unawaited(f.controller.hangup());
      clock.flushMicrotasks();
      f.now = f.now.add(const Duration(seconds: 4));
      clock.elapse(const Duration(seconds: 4));
      expect(f.controller.snapshot.elapsedSeconds, 3);
      unawaited(f.close());
      clock.flushMicrotasks();
      expect(clock.pendingTimers, isEmpty);
    }),
  );
}
