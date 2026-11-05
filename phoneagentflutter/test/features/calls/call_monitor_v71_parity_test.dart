import 'dart:async';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/calls/data/preview_call_monitor.dart';
import 'package:phone_agent/features/calls/domain/call_session.dart';
import 'package:phone_agent/features/calls/presentation/controller/call_monitor_controller.dart';
import '../../support/call_monitor_fixture.dart';
import 'package:phone_agent/features/calls/presentation/controller/call_presentation.dart';

void main() {
  test('ticket waits for physical connection; terminal cancels waiting', () {
    fakeAsync((clock) {
      var requests = 0;
      final controller = CallMonitorController(
        loadTicket: (_) async {
          requests++;
          return monitorTicket();
        },
        createMedia: TestMonitorMedia.new,
        isCurrent: () => true,
      );
      final target = CallSessionTarget(callId: 'call');
      controller.bind(target, active: true, connected: false);
      unawaited(controller.toggle());
      clock.flushMicrotasks();
      clock.elapse(const Duration(seconds: 30));
      expect(requests, 0);
      controller.bind(target, active: true, connected: true);
      clock.flushMicrotasks();
      expect(requests, 1);
      expect(controller.snapshot.playing, true);
      unawaited(controller.stop());
      clock.flushMicrotasks();
      controller.bind(target, active: true, connected: false);
      unawaited(controller.toggle());
      clock.flushMicrotasks();
      controller.bind(null, active: false, connected: false);
      clock.flushMicrotasks();
      controller.bind(target, active: false, connected: true);
      clock.flushMicrotasks();
      expect(requests, 1);
      expect(controller.snapshot.phase, CallMonitorPhase.off);
      controller.dispose();
      clock.flushMicrotasks();
      expect(clock.pendingTimers, isEmpty);
    });
  });
  test('no first PCM times out with bounded retries and no false playing', () {
    fakeAsync((clock) {
      final ports = PreviewCallMonitor();
      final controller = ports.create();
      controller.bind(CallSessionTarget(callId: 'call'), active: true);
      unawaited(controller.toggle());
      clock.flushMicrotasks();
      for (var attempt = 1; attempt <= 4; attempt++) {
        expect(ports.tickets, attempt);
        expect(controller.snapshot.playing, false);
        clock.elapse(const Duration(seconds: 10));
        clock.flushMicrotasks();
        clock.elapse(const Duration(milliseconds: 800));
        clock.flushMicrotasks();
      }
      expect(ports.tickets, 4);
      expect(controller.snapshot.phase, CallMonitorPhase.failed);
      clock.elapse(const Duration(seconds: 30));
      expect(ports.tickets, 4);
      controller.dispose();
      ports.dispose();
      clock.flushMicrotasks();
      expect(clock.pendingTimers, isEmpty);
    });
  });
  test('late ticket after eight-second timeout cannot start old output', () {
    fakeAsync((clock) {
      final tickets = <Completer<CallMonitorTicket>>[];
      var media = 0;
      final controller = CallMonitorController(
        loadTicket: (_) {
          final gate = Completer<CallMonitorTicket>();
          tickets.add(gate);
          return gate.future;
        },
        createMedia: () {
          media++;
          return TestMonitorMedia();
        },
        isCurrent: () => true,
      );
      controller.bind(CallSessionTarget(callId: 'call'), active: true);
      unawaited(controller.toggle());
      clock.flushMicrotasks();
      clock.elapse(const Duration(seconds: 8));
      expect(controller.snapshot.phase, CallMonitorPhase.reconnecting);
      tickets.single.complete(monitorTicket());
      clock.flushMicrotasks();
      expect(media, 0);
      clock.elapse(const Duration(milliseconds: 800));
      expect(tickets, hasLength(2));
      unawaited(controller.stop());
      clock.flushMicrotasks();
      tickets.last.complete(monitorTicket());
      clock.flushMicrotasks();
      expect(media, 0);
      controller.dispose();
      clock.flushMicrotasks();
      expect(clock.pendingTimers, isEmpty);
    });
  });
  test('socket handshake does not claim playback before accepted PCM', () {
    fakeAsync((clock) {
      final ports = PreviewCallMonitor();
      final controller = ports.create();
      controller.bind(CallSessionTarget(callId: 'call'), active: true);
      unawaited(controller.toggle());
      clock.flushMicrotasks();
      expect(ports.socket, isNotNull);
      expect(controller.snapshot.phase, CallMonitorPhase.connecting);
      ports.pcm();
      clock.flushMicrotasks();
      expect(controller.snapshot.phase, CallMonitorPhase.playing);
      unawaited(controller.stop());
      clock.flushMicrotasks();
      controller.dispose();
      ports.dispose();
      clock.flushMicrotasks();
      expect(clock.pendingTimers, isEmpty);
    });
  });
  test('output may be preselected without starting monitor', () {
    fakeAsync((clock) {
      final ports = PreviewCallMonitor();
      final controller = ports.create();
      controller.bind(CallSessionTarget(callId: 'call'), active: true);
      unawaited(controller.select(CallAudioSource.speaker));
      clock.flushMicrotasks();
      expect(controller.snapshot.source, CallAudioSource.speaker);
      expect(ports.tickets, 0);
      expect(ports.socket, isNull);
      unawaited(controller.toggle());
      clock.flushMicrotasks();
      ports.pcm();
      clock.flushMicrotasks();
      expect(controller.snapshot.source, CallAudioSource.speaker);
      expect(controller.snapshot.playing, true);
      unawaited(controller.toggle());
      clock.flushMicrotasks();
      unawaited(controller.select(CallAudioSource.earpiece));
      clock.flushMicrotasks();
      expect(controller.snapshot.phase, CallMonitorPhase.muted);
      expect(controller.snapshot.source, CallAudioSource.earpiece);
      unawaited(controller.stop());
      clock.flushMicrotasks();
      controller.dispose();
      ports.dispose();
      clock.flushMicrotasks();
    });
  });
}
