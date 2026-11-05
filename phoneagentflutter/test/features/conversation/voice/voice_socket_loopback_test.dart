import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/data/voice/task_asr_session.dart';
import 'package:phone_agent/features/conversation/data/voice/task_tts_session.dart';
import 'package:phone_agent/features/conversation/data/voice/task_voice_endpoint.dart';
import 'package:phone_agent/features/conversation/domain/voice/voice_gateway_event.dart';

void main() {
  test(
    'real loopback ASR handshake, PCM, release, late final and finish',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final peers = <WebSocket>[];
      addTearDown(() async {
        for (final peer in peers) {
          await peer.close();
        }
        await server.close(force: true);
      });
      final controls = <String>[];
      final frame = Completer<List<int>>(), finished = Completer<void>();
      final requestPath = Completer<Uri>();
      server.listen((request) async {
        requestPath.complete(request.uri);
        final socket = await WebSocketTransformer.upgrade(request);
        peers.add(socket);
        socket.listen((data) {
          if (data is List<int>) {
            if (!frame.isCompleted) frame.complete(data);
            return;
          }
          final type = (jsonDecode(data as String) as Map)['type'] as String;
          controls.add(type);
          if (type == 'stop_capture') {
            socket.add('{"type":"final","text":"synthetic final"}');
          }
          if (type == 'finish' && !finished.isCompleted) finished.complete();
        });
        socket.add('{"type":"ready"}');
      });
      final session = TaskAsrSession();
      addTearDown(session.cancel);
      final ready = Completer<void>(), result = Completer<String>();
      session.events.listen((event) {
        if (event is VoiceReady) ready.complete();
        if (event is VoiceTranscript) result.complete(event.text);
      });
      final base = Uri.parse(
        'http://127.0.0.1:${server.port}/aiassistant-api/',
      );
      await session.start(TaskVoiceEndpoint.asr(base, 'en'));
      await ready.future.timeout(const Duration(seconds: 3));
      expect(session.sendPcm(Uint8List.fromList([1, 2, 3, 4])), isTrue);
      expect(await frame.future.timeout(const Duration(seconds: 3)), [
        1,
        2,
        3,
        4,
      ]);
      session.release();
      expect(
        await result.future.timeout(const Duration(seconds: 3)),
        'synthetic final',
      );
      await session.cancel();
      await finished.future.timeout(const Duration(seconds: 3));
      expect(controls, ['start_capture', 'stop_capture', 'finish']);
      expect(
        (await requestPath.future).path,
        '/aiassistant-api/ws/assistant/task-voice/asr',
      );
      expect((await requestPath.future).queryParameters, {
        'languageCode': 'en-US',
      });
    },
  );
  test(
    'real loopback TTS sends selected speaker and preserves binary tail',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final peers = <WebSocket>[];
      addTearDown(() async {
        for (final peer in peers) {
          await peer.close();
        }
        await server.close(force: true);
      });
      final payload = Completer<Map>();
      server.listen((request) async {
        final socket = await WebSocketTransformer.upgrade(request);
        peers.add(socket);
        socket.listen((data) {
          final control = jsonDecode(data as String) as Map;
          if (control['type'] != 'synthesize') return;
          payload.complete(control);
          socket.add(Uint8List.fromList([0, 1, 2, 3]));
          socket.add('{"type":"complete"}');
        });
        socket.add('{"type":"ready"}');
      });
      final session = TaskTtsSession();
      addTearDown(session.cancel);
      final events = <VoiceGatewayEvent>[];
      final done = Completer<void>();
      session.events.listen((event) {
        events.add(event);
        if (event is VoiceSynthesisComplete) done.complete();
      });
      final base = Uri.parse(
        'http://127.0.0.1:${server.port}/aiassistant-api/',
      );
      await session.start(
        TaskVoiceEndpoint.tts(base),
        text: 'synthetic',
        speaker: 'chosen',
      );
      await done.future.timeout(const Duration(seconds: 3));
      expect(await payload.future, {
        'type': 'synthesize',
        'text': 'synthetic',
        'speaker': 'chosen',
        'generation': 1,
      });
      expect(events.whereType<VoicePcmChunk>().single.bytes, [0, 1, 2, 3]);
      expect(events.last, isA<VoiceSynthesisComplete>());
      expect(session.closed, isFalse);
    },
  );
  test('real connection refusal becomes a sanitized failure', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final port = server.port;
    await server.close(force: true);
    final session = TaskAsrSession();
    final events = <VoiceGatewayEvent>[];
    final done = Completer<void>();
    session.events.listen(events.add, onDone: done.complete);
    await session.start(Uri.parse('ws://127.0.0.1:$port/'));
    await done.future.timeout(const Duration(seconds: 3));
    expect(
      events.whereType<VoiceGatewayFailure>().single.message,
      'connect_failed',
    );
  });
}
