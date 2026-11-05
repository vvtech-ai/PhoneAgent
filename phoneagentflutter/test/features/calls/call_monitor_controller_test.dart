import 'dart:async';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/calls/domain/call_monitor_media.dart';
import 'package:phone_agent/features/calls/domain/call_session.dart';
import 'package:phone_agent/features/calls/presentation/controller/call_monitor_controller.dart';
import 'package:phone_agent/features/calls/presentation/controller/call_presentation.dart';
import '../../support/call_monitor_fixture.dart';

class Fixture {
  var current = true, failTicket = false;
  int tickets = 0;
  Completer<CallMonitorTicket>? ticketGate;
  final media = <TestMonitorMedia>[];
  late final controller = CallMonitorController(
    isCurrent: () => current,
    loadTicket: (_) async {
      tickets++;
      if (failTicket) throw const CallMonitorFailure('private');
      return ticketGate == null ? monitorTicket() : ticketGate!.future;
    },
    createMedia: () {
      final value = TestMonitorMedia();
      media.add(value);
      return value;
    },
  );
  void bind([String id = 'call']) => controller.bind(
    CallSessionTarget(taskId: 'task', callId: id),
    active: true,
  );
}

void main() {
  test(
    'explicit start, mute/resume and routes share ticket/socket; no automatic start',
    () => fakeAsync((clock) {
      final f = Fixture()..bind();
      clock.flushMicrotasks();
      expect(f.tickets, 0);
      unawaited(f.controller.toggle());
      clock.flushMicrotasks();
      expect(f.controller.snapshot.phase, CallMonitorPhase.playing);
      unawaited(f.controller.select(CallAudioSource.bluetooth));
      clock.flushMicrotasks();
      expect(f.controller.snapshot.source, CallAudioSource.bluetooth);
      unawaited(f.controller.toggle());
      clock.flushMicrotasks();
      expect(f.controller.snapshot.phase, CallMonitorPhase.muted);
      unawaited(f.controller.select(CallAudioSource.speaker));
      clock.flushMicrotasks();
      expect(f.controller.snapshot.source, CallAudioSource.speaker);
      unawaited(f.controller.toggle());
      clock.flushMicrotasks();
      expect(f.tickets, 1);
      unawaited(f.controller.select(CallAudioSource.bluetooth));
      clock.flushMicrotasks();
      f.media.single.bluetooth = false;
      clock.elapse(const Duration(seconds: 1));
      expect(f.controller.snapshot.source, CallAudioSource.earpiece);
      expect(f.controller.snapshot.bluetoothAvailable, isFalse);
      f.controller.dispose();
      clock.flushMicrotasks();
      expect(clock.pendingTimers, isEmpty);
    }),
  );
  test(
    'initial failure plus exactly three retries at 800ms; explicit retry resets',
    () => fakeAsync((clock) {
      final f = Fixture()
        ..failTicket = true
        ..bind();
      unawaited(f.controller.toggle());
      clock.flushMicrotasks();
      for (var i = 1; i <= 3; i++) {
        expect(f.tickets, i);
        clock.elapse(const Duration(milliseconds: 799));
        expect(f.tickets, i);
        clock.elapse(const Duration(milliseconds: 1));
      }
      expect(f.tickets, 4);
      expect(f.controller.snapshot.phase, CallMonitorPhase.failed);
      clock.elapse(const Duration(seconds: 10));
      expect(f.tickets, 4);
      f.failTicket = false;
      unawaited(f.controller.toggle());
      clock.flushMicrotasks();
      expect(f.controller.snapshot.phase, CallMonitorPhase.playing);
      f.controller.dispose();
      clock.flushMicrotasks();
    }),
  );
  test(
    'disconnect renews ticket; stop during delay cancels reconnect',
    () => fakeAsync((clock) {
      final f = Fixture()..bind();
      unawaited(f.controller.toggle());
      clock.flushMicrotasks();
      f.media.single.events.add(null);
      clock.flushMicrotasks();
      expect(f.controller.snapshot.phase, CallMonitorPhase.reconnecting);
      clock.elapse(const Duration(milliseconds: 800));
      expect(f.tickets, 2);
      expect(f.media.first.closes, 1);
      f.media.last.events.add(null);
      clock.flushMicrotasks();
      unawaited(f.controller.stop());
      clock.flushMicrotasks();
      clock.elapse(const Duration(seconds: 2));
      expect(f.tickets, 2);
      expect(f.controller.snapshot.phase, CallMonitorPhase.off);
      f.controller.dispose();
      clock.flushMicrotasks();
    }),
  );
  for (final action in ['terminal', 'call', 'account', 'dispose']) {
    test(
      '$action invalidates late ticket without starting media',
      () => fakeAsync((clock) {
        final f = Fixture()
          ..ticketGate = Completer<CallMonitorTicket>()
          ..bind();
        unawaited(f.controller.toggle());
        clock.flushMicrotasks();
        switch (action) {
          case 'terminal':
            f.controller.bind(null, active: false);
          case 'call':
            f.bind('other');
          case 'account':
            f.current = false;
          case 'dispose':
            f.controller.dispose();
        }
        f.ticketGate!.complete(monitorTicket());
        clock.flushMicrotasks();
        expect(f.media, isEmpty);
        if (f.controller.mounted) f.controller.dispose();
        clock.flushMicrotasks();
        expect(clock.pendingTimers, isEmpty);
      }),
    );
  }
  test(
    'native playback interruption stops without automatic reconnect',
    () => fakeAsync((clock) {
      final f = Fixture()..bind();
      unawaited(f.controller.toggle());
      clock.flushMicrotasks();
      f.media.single.events.addError(const CallMonitorFailure('output_failed'));
      clock.flushMicrotasks();
      expect(f.controller.snapshot.phase, CallMonitorPhase.failed);
      expect(f.controller.snapshot.error, contains('已中断'));
      clock.elapse(const Duration(seconds: 5));
      expect(f.tickets, 1);
      expect(f.media.single.closes, 1);
      unawaited(f.controller.toggle());
      clock.flushMicrotasks();
      expect(f.tickets, 2);
      f.controller.dispose();
      clock.flushMicrotasks();
    }),
  );
  test(
    'close failure blocks reconnect; explicit toggle retries cleanup first',
    () => fakeAsync((clock) {
      final f = Fixture()..bind();
      unawaited(f.controller.toggle());
      clock.flushMicrotasks();
      f.media.single.failClose = true;
      f.media.single.events.add(null);
      clock.flushMicrotasks();
      expect(f.controller.snapshot.error, contains('释放失败'));
      clock.elapse(const Duration(seconds: 4));
      expect(f.tickets, 1);
      unawaited(f.controller.toggle());
      clock.flushMicrotasks();
      expect(f.tickets, 1);
      f.media.single.failClose = false;
      unawaited(f.controller.toggle());
      clock.flushMicrotasks();
      expect(f.tickets, 2);
      f.controller.dispose();
      clock.flushMicrotasks();
    }),
  );
  test(
    'late route poll cannot override newer selection; controls single-flight',
    () => fakeAsync((clock) {
      final f = Fixture()..bind();
      unawaited(f.controller.toggle());
      clock.flushMicrotasks();
      final media = f.media.single;
      media.routeGate = Completer<CallMonitorRoute>();
      unawaited(f.controller.refreshRoute());
      clock.flushMicrotasks();
      unawaited(f.controller.select(CallAudioSource.speaker));
      clock.flushMicrotasks();
      media.routeGate!.complete(const CallMonitorRoute());
      clock.flushMicrotasks();
      expect(f.controller.snapshot.source, CallAudioSource.speaker);
      media.controlGate = Completer<void>();
      unawaited(f.controller.toggle());
      unawaited(f.controller.toggle());
      clock.flushMicrotasks();
      expect(media.controls, 1);
      media.controlGate!.complete();
      clock.flushMicrotasks();
      f.controller.dispose();
      clock.flushMicrotasks();
    }),
  );
  test(
    'route failure retains selected route; account expiry releases active output',
    () => fakeAsync((clock) {
      final f = Fixture()..bind();
      unawaited(f.controller.toggle());
      clock.flushMicrotasks();
      f.media.single.failRoute = true;
      unawaited(f.controller.select(CallAudioSource.speaker));
      clock.flushMicrotasks();
      expect(f.controller.snapshot.source, CallAudioSource.earpiece);
      expect(f.controller.snapshot.error, contains('未成功'));
      f.current = false;
      clock.elapse(const Duration(seconds: 1));
      expect(f.media.single.closes, 1);
      f.controller.dispose();
      clock.flushMicrotasks();
    }),
  );
  test('web production refuses without requesting ticket', () async {
    var requests = 0;
    final controller = CallMonitorController(
      loadTicket: (_) async {
        requests++;
        return monitorTicket();
      },
      createMedia: TestMonitorMedia.new,
      isCurrent: () => true,
      supported: false,
    );
    controller.bind(CallSessionTarget(callId: 'call'), active: true);
    await controller.toggle();
    expect(controller.snapshot.error, contains('Web'));
    expect(requests, 0);
    controller.dispose();
  });
}
