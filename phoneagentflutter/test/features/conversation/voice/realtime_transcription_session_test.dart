import 'dart:async';
import 'dart:typed_data';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/data/voice/realtime_transcription_session.dart';
import 'package:phone_agent/features/conversation/data/voice/task_voice_endpoint.dart';
import 'package:phone_agent/features/conversation/domain/voice/voice_gateway_event.dart';
import 'voice_socket_fake.dart';

final endpoint = TaskVoiceEndpoint.transcription(
  Uri.parse('https://synthetic.invalid/aiassistant-api/'),
  userId: 'account-a',
);
void main() {
  test(
    'endpoint uses account, optional task and shared language normalization',
    () {
      expect(endpoint.scheme, 'wss');
      expect(
        endpoint.path,
        '/aiassistant-api/ws/assistant/realtime/transcription',
      );
      expect(endpoint.queryParameters, {
        'userId': 'account-a',
        'languageCode': 'zh-CN',
      });
      final withTask = TaskVoiceEndpoint.transcription(
        Uri.parse('http://synthetic.invalid'),
        userId: 'account + id',
        taskId: 'task&one',
        language: 'jp',
      );
      expect(withTask.queryParameters, {
        'userId': 'account + id',
        'taskId': 'task&one',
        'languageCode': 'ja-JP',
      });
      expect(
        () => TaskVoiceEndpoint.transcription(
          Uri.parse('https://a'),
          userId: ' ',
        ),
        throwsArgumentError,
      );
    },
  );

  test(
    'ready gates PCM; close emits no JSON controls and drops queued text',
    () {
      fakeAsync((clock) {
        final socket = VoiceSocketFake();
        final session = RealtimeTranscriptionSession(
          connector: (_) async => socket,
        );
        final events = <VoiceGatewayEvent>[];
        session.events.listen(events.add);
        session.start(endpoint);
        clock.flushMicrotasks();
        expect(session.sendPcm(Uint8List(640)), false);
        socket.emit('{"type":"final","text":"before ready"}');
        socket.emit('{"type":"ready"}');
        socket.emit('{"type":"ready"}');
        clock.flushMicrotasks();
        expect(events.whereType<VoiceReady>().length, 1);
        final frame = Uint8List(640)..[0] = 7;
        expect(session.sendPcm(frame), true);
        frame[0] = 8;
        expect((socket.sent.single as Uint8List)[0], 7);
        socket.emit('{"type":"partial","text":"now"}');
        socket.emit('{"type":"final","text":"now final"}');
        clock.flushMicrotasks();
        socket.emit('{"type":"final","text":"late"}');
        session.release();
        clock.flushMicrotasks();
        expect(events.whereType<VoiceTranscript>().map((e) => e.text), [
          'now',
          'now final',
        ]);
        expect(socket.sent.whereType<String>(), isEmpty);
        expect(socket.closes, 1);
        expect(session.sendPcm(Uint8List(2)), false);
        expect(clock.nonPeriodicTimerCount, 0);
      });
    },
  );

  test(
    '8 second deadline closes a late handshake without starting capture',
    () {
      fakeAsync((clock) {
        final pending = Completer<VoiceSocketFake>();
        final events = <VoiceGatewayEvent>[];
        final session = RealtimeTranscriptionSession(
          connector: (_) => pending.future,
        );
        session.events.listen(events.add);
        session.start(endpoint);
        clock.elapse(const Duration(seconds: 8));
        clock.flushMicrotasks();
        final socket = VoiceSocketFake();
        pending.complete(socket);
        clock.flushMicrotasks();
        expect(
          events.whereType<VoiceGatewayFailure>().single.message,
          'ready_timeout',
        );
        expect(socket.closes, 1);
        expect(socket.sent, isEmpty);
      });
    },
  );

  for (final message in [
    'bad private data',
    '{"type":"error","message":"secret"}',
    Uint8List(2),
  ]) {
    test(
      'invalid/provider frame is terminal and sanitized: ${message.runtimeType}',
      () {
        fakeAsync((clock) {
          final socket = VoiceSocketFake();
          final session = RealtimeTranscriptionSession(
            connector: (_) async => socket,
          );
          final events = <VoiceGatewayEvent>[];
          session.events.listen(events.add);
          session.start(endpoint);
          clock.flushMicrotasks();
          socket.emit(message);
          clock.flushMicrotasks();
          expect(
            events.whereType<VoiceGatewayFailure>().single.message,
            isIn(['invalid_frame', 'provider_error']),
          );
          expect(socket.closes, 1);
          expect(socket.sent, isEmpty);
        });
      },
    );
  }
}
