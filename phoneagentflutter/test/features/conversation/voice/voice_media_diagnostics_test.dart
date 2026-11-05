import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/diagnostics/diagnostic_event.dart';
import 'package:phone_agent/core/diagnostics/media_diagnostics.dart';
import 'package:phone_agent/features/conversation/data/voice/task_asr_session.dart';
import 'package:phone_agent/features/conversation/data/voice/realtime_transcription_session.dart';
import 'package:phone_agent/features/conversation/data/voice/task_tts_session.dart';
import 'package:phone_agent/features/conversation/data/voice/voice_wire.dart';
import 'voice_socket_fake.dart';

final endpoint = Uri.parse('wss://example.test/private?token=SECRET');
void main() {
  test('task TTS lifecycle failures retain stable diagnostic reasons', () {
    final events = <DiagnosticEvent>[];
    final diagnostics = MediaDiagnostics(
      events.add,
      DiagnosticMediaComponent.taskTts,
    );
    for (final code in [
      'network_changed',
      'app_lifecycle',
      'heartbeat_timeout',
      'heartbeat_send_failed',
      'transport_invalidated',
    ]) {
      diagnostics.failure(code);
    }
    expect(
      events.map((event) => event.media!.reason),
      [
        DiagnosticMediaReason.networkChanged,
        DiagnosticMediaReason.appLifecycle,
        DiagnosticMediaReason.heartbeatTimeout,
        DiagnosticMediaReason.heartbeatSendFailed,
        DiagnosticMediaReason.transportInvalidated,
      ],
    );
  });

  test(
    'task ASR connect is not ready, first send only; private transcript absent',
    () {
      fakeAsync((clock) {
        final events = <DiagnosticEvent>[];
        final socket = VoiceSocketFake();
        final session = TaskAsrSession(
          connector: (_) async => socket,
          diagnostics: MediaDiagnostics(
            events.add,
            DiagnosticMediaComponent.taskAsr,
          ),
        );
        session.events.listen((_) {});
        session.start(endpoint);
        clock.flushMicrotasks();
        expect(events.map((e) => e.media!.stage), [
          DiagnosticMediaStage.connect,
          DiagnosticMediaStage.connect,
        ]);
        socket.emit('{"type":"ready"}');
        clock.flushMicrotasks();
        for (var i = 0; i < 100; i++) {
          session.sendPcm(Uint8List(640));
        }
        socket.emit('{"type":"final","text":"PRIVATE TRANSCRIPT"}');
        clock.flushMicrotasks();
        expect(events.length, 4);
        session.cancel();
        clock.flushMicrotasks();
        expect(events.last.media!.stage, DiagnosticMediaStage.close);
        final encoded = jsonEncode(events.map((e) => e.toJson()).toList());
        expect(encoded, isNot(contains('SECRET')));
        expect(encoded, isNot(contains('PRIVATE TRANSCRIPT')));
        expect(encoded, isNot(contains('example.test')));
        expect(clock.nonPeriodicTimerCount, 0);
      });
    },
  );

  test(
    'ready timeout and fallback provider error retain distinct fixed components',
    () {
      fakeAsync((clock) {
        final events = <DiagnosticEvent>[];
        final primary = TaskAsrSession(
          connector: (_) async => VoiceSocketFake(),
          diagnostics: MediaDiagnostics(
            events.add,
            DiagnosticMediaComponent.taskAsr,
          ),
        );
        primary.events.listen((_) {});
        primary.start(endpoint);
        clock.flushMicrotasks();
        clock.elapse(const Duration(seconds: 10));
        clock.flushMicrotasks();
        final fallbackSocket = VoiceSocketFake();
        final fallback = RealtimeTranscriptionSession(
          connector: (_) async => fallbackSocket,
          diagnostics: MediaDiagnostics(
            events.add,
            DiagnosticMediaComponent.realtimeAsr,
          ),
        );
        fallback.events.listen((_) {});
        fallback.start(endpoint);
        clock.flushMicrotasks();
        fallbackSocket.emit('{"type":"error","message":"PRIVATE ERROR"}');
        clock.flushMicrotasks();
        final failures = events
            .where((e) => e.media!.stage == DiagnosticMediaStage.protocol)
            .toList();
        expect(failures.map((e) => e.media!.reason), [
          DiagnosticMediaReason.readyTimeout,
          DiagnosticMediaReason.providerError,
        ]);
        expect(failures.map((e) => e.media!.component), [
          DiagnosticMediaComponent.taskAsr,
          DiagnosticMediaComponent.realtimeAsr,
        ]);
        expect(
          jsonEncode(events.map((e) => e.toJson()).toList()),
          isNot(contains('PRIVATE')),
        );
        expect(clock.nonPeriodicTimerCount, 0);
      });
    },
  );

  test(
    'late connection after cancel is closed but never records connected success',
    () async {
      final events = <DiagnosticEvent>[];
      final pending = Completer<VoiceSocketFake>();
      final socket = VoiceSocketFake();
      final wire = VoiceWire(
        (_) => pending.future,
        onMessage: (_) => fail('late'),
        onFailure: (_) => fail('late'),
        onClosed: () => fail('late'),
        diagnostics: MediaDiagnostics(
          events.add,
          DiagnosticMediaComponent.taskAsr,
        ),
      );
      final opening = wire.open(endpoint);
      await wire.close();
      pending.complete(socket);
      await opening;
      expect(socket.closes, 1);
      expect(
        events
            .where((e) => e.media!.stage == DiagnosticMediaStage.connect)
            .map((e) => e.result),
        [DiagnosticResult.started, DiagnosticResult.cancelled],
      );
    },
  );

  test(
    'wire connect and cleanup failures do not retain exceptions or change best effort',
    () async {
      final events = <DiagnosticEvent>[];
      final failures = <String>[];
      final diagnostics = MediaDiagnostics(
        events.add,
        DiagnosticMediaComponent.taskTts,
      );
      final wire = VoiceWire(
        (_) async => throw StateError('private-token'),
        onMessage: (_) {},
        onFailure: failures.add,
        onClosed: () {},
        diagnostics: diagnostics,
      );
      await wire.open(endpoint);
      expect(failures, ['connect_failed']);
      expect(events.last.result, DiagnosticResult.failed);
      final socket = _BrokenCloseSocket();
      final closeWire = VoiceWire(
        (_) async => socket,
        onMessage: (_) {},
        onFailure: failures.add,
        onClosed: () {},
        diagnostics: diagnostics,
      );
      await closeWire.open(endpoint);
      await closeWire.close();
      expect(events.last.media!.stage, DiagnosticMediaStage.close);
      expect(events.last.result, DiagnosticResult.failed);
      expect(
        jsonEncode(events.map((e) => e.toJson()).toList()),
        isNot(contains('private')),
      );
    },
  );

  test(
    'TTS protocol completion records received, not hardware playback success',
    () {
      fakeAsync((clock) {
        final events = <DiagnosticEvent>[];
        final socket = VoiceSocketFake();
        final session = TaskTtsSession(
          connector: (_) async => socket,
          diagnostics: MediaDiagnostics(
            events.add,
            DiagnosticMediaComponent.taskTts,
          ),
        );
        session.events.listen((_) {});
        session.start(
          endpoint,
          text: 'PRIVATE TEXT',
          speaker: 'PRIVATE SPEAKER',
        );
        clock.flushMicrotasks();
        socket.emit('{"type":"ready"}');
        clock.flushMicrotasks();
        for (var i = 0; i < 100; i++) {
          socket.emit(Uint8List(2));
        }
        socket.emit('{"type":"complete"}');
        clock.flushMicrotasks();
        expect(
          events
              .where((e) => e.media!.stage == DiagnosticMediaStage.receive)
              .length,
          1,
        );
        final complete = events.singleWhere(
          (e) => e.media!.stage == DiagnosticMediaStage.complete,
        );
        expect(complete.result, DiagnosticResult.received);
        expect(
          events.any((e) => e.media!.stage == DiagnosticMediaStage.play),
          isFalse,
        );
        expect(
          jsonEncode(events.map((e) => e.toJson()).toList()),
          isNot(contains('PRIVATE')),
        );
        expect(clock.nonPeriodicTimerCount, 0);
      });
    },
  );

  test('throwing sink preserves protocol error and timer cleanup', () {
    fakeAsync((clock) {
      final session = TaskTtsSession(
        connector: (_) async => throw StateError('transport'),
        diagnostics: MediaDiagnostics(
          (_) => throw StateError('sink'),
          DiagnosticMediaComponent.taskTts,
        ),
      );
      final events = <Object>[];
      session.events.listen(events.add);
      session.start(endpoint, text: 'test', speaker: 'test');
      clock.flushMicrotasks();
      expect(events.length, 1);
      expect(clock.nonPeriodicTimerCount, 0);
    });
  });
}

class _BrokenCloseSocket extends VoiceSocketFake {
  @override
  Future<void> close() async {
    await super.close();
    throw StateError('private close detail');
  }
}
