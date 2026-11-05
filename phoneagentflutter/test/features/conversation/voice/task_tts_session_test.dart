import 'dart:convert';
import 'dart:typed_data';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/data/voice/task_tts_session.dart';
import 'package:phone_agent/features/conversation/domain/voice/voice_gateway_event.dart';
import 'voice_socket_fake.dart';

final endpoint = Uri.parse('ws://localhost/ws/assistant/task-voice/tts');
void main() {
  test('prewarm accepts idle ready and pong without synthesis', () {
    fakeAsync((clock) {
      final socket = VoiceSocketFake();
      final dynamic session = TaskTtsSession(
        connector: (_) async => socket,
        heartbeatInterval: const Duration(seconds: 1),
      );
      session.prewarm(endpoint);
      clock.flushMicrotasks();
      socket.emit('{"type":"ready"}');
      clock.flushMicrotasks();
      expect(socket.sent, isEmpty);
      clock.elapse(const Duration(seconds: 1));
      expect(jsonDecode(socket.sent.single as String)['type'], 'ping');
      socket.emit('{"type":"pong"}');
      clock.flushMicrotasks();
      clock.elapse(const Duration(seconds: 1));
      expect(socket.closes, 0);
      session.start(endpoint, text: 'A', speaker: 'synthetic');
      clock.flushMicrotasks();
      expect(jsonDecode(socket.sent.last as String)['text'], 'A');
      session.cancel();
      clock.flushMicrotasks();
    });
  });
  test('expired snapshot spends the existing fresh retry once', () {
    fakeAsync((clock) {
      final sockets = <VoiceSocketFake>[];
      final events = <VoiceGatewayEvent>[];
      final session = TaskTtsSession(
        connector: (_) async {
          final socket = VoiceSocketFake();
          sockets.add(socket);
          return socket;
        },
      );
      session.events.listen(events.add);
      session.start(endpoint, text: 'A', speaker: 'synthetic');
      clock.flushMicrotasks();
      sockets.single.emit('{"type":"ready"}');
      sockets.single.emit('{"type":"error","code":"reconnect_required"}');
      clock.flushMicrotasks();
      expect(sockets, hasLength(2));
      sockets.last.emit('{"type":"ready"}');
      clock.flushMicrotasks();
      expect(jsonDecode(sockets.last.sent.single as String)['text'], 'A');
      sockets.last.emit('{"type":"error","code":"reconnect_required"}');
      clock.flushMicrotasks();
      expect(events.whereType<VoiceGatewayFailure>(), hasLength(1));
      expect(sockets, hasLength(2));
      session.cancel();
      clock.flushMicrotasks();
    });
  });
  test('soft completion discards unconfirmed wire before the next request', () {
    fakeAsync((clock) {
      final sockets = <VoiceSocketFake>[];
      final session = TaskTtsSession(
        connector: (_) async {
          final socket = VoiceSocketFake(closeMessagesOnClose: false);
          sockets.add(socket);
          return socket;
        },
      );
      session.start(endpoint, text: 'A', speaker: 'synthetic');
      clock.flushMicrotasks();
      sockets.single.emit('{"type":"ready"}');
      sockets.single.emit(Uint8List(2));
      clock.flushMicrotasks();
      clock.elapse(const Duration(seconds: 15));
      clock.flushMicrotasks();
      session.start(endpoint, text: 'B', speaker: 'synthetic');
      clock.flushMicrotasks();
      expect(sockets, hasLength(2));
      expect(sockets.first.closes, 1);
      session.cancel();
      clock.flushMicrotasks();
    });
  });
  test('completed synthesis keeps idle heartbeat and accepts pong', () {
    fakeAsync((clock) {
      final sockets = <VoiceSocketFake>[];
      final session = TaskTtsSession(
        heartbeatInterval: const Duration(seconds: 1),
        connector: (_) async {
          final socket = VoiceSocketFake();
          sockets.add(socket);
          return socket;
        },
      );
      session.start(endpoint, text: 'A', speaker: 'synthetic');
      clock.flushMicrotasks();
      sockets.single.emit('{"type":"ready"}');
      sockets.single.emit(Uint8List(2));
      sockets.single.emit('{"type":"complete"}');
      clock.flushMicrotasks();
      clock.elapse(const Duration(seconds: 1));
      clock.flushMicrotasks();
      expect(jsonDecode(sockets.single.sent.last as String)['type'], 'ping');
      sockets.single.emit('{"type":"pong"}');
      clock.flushMicrotasks();
      clock.elapse(const Duration(seconds: 1));
      expect(sockets.single.closes, 0);
      session.cancel();
      clock.flushMicrotasks();
    });
  });
  test('timeout uses trimmed v65 length and 15 to 60 second clamp', () {
    expect(
      TaskTtsSession.completionTimeout(' x '),
      const Duration(seconds: 15),
    );
    expect(
      TaskTtsSession.completionTimeout('x' * 100),
      const Duration(seconds: 35),
    );
    expect(
      TaskTtsSession.completionTimeout('x' * 1000),
      const Duration(seconds: 60),
    );
  });

  test(
    'single-sentence fallback disables reuse and clamps invalid timeout/retry values',
    () {
      final session = TaskTtsSession(
        firstAudioTimeout: Duration.zero,
        maxRecoveryRetries: 9,
        reuseEnabled: false,
      );
      expect(session.firstAudioTimeout, const Duration(milliseconds: 100));
    },
  );
  test(
    'ready sends once; prebuffer, subsequent chunk and tail remain ordered',
    () {
      fakeAsync((clock) {
        final socket = VoiceSocketFake();
        final session = TaskTtsSession(connector: (_) async => socket);
        final events = <VoiceGatewayEvent>[];
        session.events.listen(events.add);
        session.start(endpoint, text: 'synthetic text', speaker: 'synthetic');
        clock.flushMicrotasks();
        expect(socket.sent, isEmpty);
        socket.emit('{"type":"ready"}');
        socket.emit('{"type":"ready"}');
        clock.flushMicrotasks();
        expect(socket.sent.length, 1);
        expect(jsonDecode(socket.sent.single as String)['type'], 'synthesize');
        socket.emit(Uint8List(12000));
        clock.flushMicrotasks();
        expect(events.whereType<VoicePcmChunk>(), isEmpty);
        socket.emit(Uint8List(12000));
        socket.emit(Uint8List(5760));
        socket.emit(Uint8List(2));
        socket.emit('{"type":"complete"}');
        clock.flushMicrotasks();
        expect(events.whereType<VoicePcmChunk>().map((e) => e.bytes.length), [
          24000,
          5760,
          2,
        ]);
        expect(events.last, isA<VoiceSynthesisComplete>());
        expect((events.last as VoiceSynthesisComplete).softTimeout, isFalse);
        expect(socket.closes, 0);
        session.cancel();
        clock.flushMicrotasks();
        expect(socket.closes, 1);
        expect(clock.nonPeriodicTimerCount, 0);
      });
    },
  );

  test(
    'idle transport invalidation closes only the wire and keeps session reusable',
    () {
      fakeAsync((clock) {
        final sockets = <VoiceSocketFake>[];
        final session = TaskTtsSession(
          connector: (_) async {
            final socket = VoiceSocketFake();
            sockets.add(socket);
            return socket;
          },
        );
        session.start(endpoint, text: 'first', speaker: 'synthetic');
        clock.flushMicrotasks();
        sockets.single.emit('{"type":"ready"}');
        clock.flushMicrotasks();
        session.invalidateTransport();
        clock.flushMicrotasks();
        expect(sockets.single.closes, 1);
        expect(session.closed, isFalse);
        session.cancel();
        clock.flushMicrotasks();
      });
    },
  );
  for (final recover in [true, false]) {
    test('zero audio retries once, recover=$recover', () {
      fakeAsync((clock) {
        final sockets = <VoiceSocketFake>[];
        final session = TaskTtsSession(
          connector: (_) async {
            final socket = VoiceSocketFake();
            sockets.add(socket);
            return socket;
          },
        );
        final events = <VoiceGatewayEvent>[];
        session.events.listen(events.add);
        session.start(endpoint, text: '合成测试', speaker: 'synthetic');
        clock.flushMicrotasks();
        sockets[0].emit('{"type":"ready"}');
        sockets[0].emit('{"type":"complete"}');
        clock.flushMicrotasks();
        expect(sockets, hasLength(2));
        expect(sockets[0].closes, 1);
        sockets[1].emit('{"type":"ready"}');
        if (recover) sockets[1].emit(Uint8List(2));
        sockets[1].emit('{"type":"complete"}');
        clock.flushMicrotasks();
        expect(
          events.whereType<VoiceSynthesisComplete>().length,
          recover ? 1 : 0,
        );
        expect(events.whereType<VoiceGatewayFailure>().length, recover ? 0 : 1);
        expect(sockets, hasLength(2));
        expect(clock.nonPeriodicTimerCount, 0);
      });
    });
  }
  test(
    'first audio timeout retries on a fresh connection and then fails once',
    () {
      fakeAsync((clock) {
        final sockets = <VoiceSocketFake>[];
        final session = TaskTtsSession(
          connector: (_) async {
            final socket = VoiceSocketFake();
            sockets.add(socket);
            return socket;
          },
        );
        final events = <VoiceGatewayEvent>[];
        session.events.listen(events.add);
        session.start(endpoint, text: 'x', speaker: 'synthetic');
        clock.flushMicrotasks();
        sockets[0].emit('{"type":"ready"}');
        clock.flushMicrotasks();
        clock.elapse(const Duration(seconds: 5));
        clock.flushMicrotasks();
        expect(sockets, hasLength(2));
        sockets[1].emit('{"type":"ready"}');
        clock.flushMicrotasks();
        expect(
          jsonDecode(sockets[1].sent.whereType<String>().single)['type'],
          'synthesize',
        );
        clock.elapse(const Duration(seconds: 5));
        clock.flushMicrotasks();
        expect(
          events.whereType<VoiceGatewayFailure>().single.message,
          'first_audio_timeout',
        );
        expect(events.whereType<VoiceSynthesisComplete>(), isEmpty);
        expect(jsonDecode(sockets[0].sent.last as String)['type'], 'cancel');
        expect(jsonDecode(sockets[1].sent.last as String)['type'], 'cancel');
        expect(sockets[0].closes, 1);
        expect(sockets[1].closes, 1);
      });
    },
  );

  test(
    'two-second silent TTS retry rejects late PCM and stops after one retry',
    () {
      fakeAsync((clock) {
        final sockets = <VoiceSocketFake>[];
        final events = <VoiceGatewayEvent>[];
        final session = TaskTtsSession(
          firstAudioTimeout: const Duration(seconds: 2),
          connector: (_) async {
            final socket = VoiceSocketFake(closeMessagesOnClose: false);
            sockets.add(socket);
            return socket;
          },
        );
        session.events.listen(events.add);

        session.start(endpoint, text: 'x', speaker: 'synthetic');
        clock.flushMicrotasks();
        sockets.single.emit('{"type":"ready"}');
        clock.flushMicrotasks();
        clock.elapse(const Duration(milliseconds: 1999));
        clock.flushMicrotasks();
        expect(sockets, hasLength(1));

        clock.elapse(const Duration(milliseconds: 1));
        clock.flushMicrotasks();
        expect(sockets, hasLength(2));
        expect(sockets.first.closes, 1);
        sockets.first.emit(Uint8List.fromList([1, 0]));
        sockets.first.emit('{"type":"complete"}');
        sockets.last.emit('{"type":"ready"}');
        clock.flushMicrotasks();
        expect(events.whereType<VoicePcmChunk>(), isEmpty);
        expect(events.whereType<VoiceSynthesisComplete>(), isEmpty);
        expect(
          jsonDecode(sockets.last.sent.whereType<String>().single)['type'],
          'synthesize',
        );

        clock.elapse(const Duration(seconds: 2));
        clock.flushMicrotasks();
        expect(sockets, hasLength(2));
        expect(events.whereType<VoicePcmChunk>(), isEmpty);
        expect(events.whereType<VoiceSynthesisComplete>(), isEmpty);
        expect(
          events.whereType<VoiceGatewayFailure>().single.message,
          'first_audio_timeout',
        );
        session.cancel();
        clock.flushMicrotasks();
      });
    },
  );

  test('late events from the replaced connection are discarded', () {
    fakeAsync((clock) {
      final sockets = <VoiceSocketFake>[];
      final session = TaskTtsSession(
        connector: (_) async {
          final socket = VoiceSocketFake(closeMessagesOnClose: false);
          sockets.add(socket);
          return socket;
        },
      );
      final events = <VoiceGatewayEvent>[];
      session.events.listen(events.add);
      session.start(endpoint, text: 'x', speaker: 'synthetic');
      clock.flushMicrotasks();
      sockets[0].emit('{"type":"ready"}');
      clock.flushMicrotasks();
      clock.elapse(const Duration(seconds: 5));
      sockets[0].emit(Uint8List(2));
      sockets[0].emit('{"type":"complete"}');
      clock.flushMicrotasks();
      sockets[1].emit('{"type":"ready"}');
      sockets[1].emit(Uint8List(2));
      sockets[1].emit('{"type":"complete"}');
      clock.flushMicrotasks();
      expect(events.whereType<VoicePcmChunk>().single.bytes.length, 2);
      expect(events.whereType<VoiceSynthesisComplete>(), hasLength(1));
    });
  });
  test(
    'completion timeout with bytes flushes tail and explicitly soft completes',
    () {
      fakeAsync((clock) {
        final socket = VoiceSocketFake();
        final session = TaskTtsSession(connector: (_) async => socket);
        final events = <VoiceGatewayEvent>[];
        session.events.listen(events.add);
        session.start(endpoint, text: 'x', speaker: 'synthetic');
        clock.flushMicrotasks();
        socket.emit('{"type":"ready"}');
        socket.emit(Uint8List(2));
        clock.flushMicrotasks();
        clock.elapse(const Duration(seconds: 15));
        clock.flushMicrotasks();
        expect(events.whereType<VoicePcmChunk>().single.bytes.length, 2);
        expect(
          events.whereType<VoiceSynthesisComplete>().single.softTimeout,
          isTrue,
        );
        expect(events.whereType<VoiceGatewayFailure>(), isEmpty);
      });
    },
  );
  test('cancel discards buffered PCM and does not emit completion', () {
    fakeAsync((clock) {
      final socket = VoiceSocketFake();
      final session = TaskTtsSession(connector: (_) async => socket);
      final events = <VoiceGatewayEvent>[];
      session.events.listen(events.add);
      session.start(endpoint, text: 'x', speaker: 'synthetic');
      clock.flushMicrotasks();
      socket.emit('{"type":"ready"}');
      socket.emit(Uint8List(2));
      clock.flushMicrotasks();
      socket.emit('{"type":"complete"}');
      session.cancel();
      clock.flushMicrotasks();
      expect(events.whereType<VoiceSynthesisComplete>(), isEmpty);
      expect(events.whereType<VoicePcmChunk>(), isEmpty);
      expect(clock.nonPeriodicTimerCount, 0);
    });
  });
  test('audio over limit fails explicitly without unbounded buffering', () {
    fakeAsync((clock) {
      final socket = VoiceSocketFake();
      final session = TaskTtsSession(
        connector: (_) async => socket,
        maxAudioBytes: 10,
      );
      final events = <VoiceGatewayEvent>[];
      session.events.listen(events.add);
      session.start(endpoint, text: 'x', speaker: 'synthetic');
      clock.flushMicrotasks();
      socket.emit('{"type":"ready"}');
      socket.emit(Uint8List(12));
      clock.flushMicrotasks();
      expect(
        events.whereType<VoiceGatewayFailure>().single.message,
        'audio_limit',
      );
      expect(events.whereType<VoicePcmChunk>(), isEmpty);
    });
  });
}
