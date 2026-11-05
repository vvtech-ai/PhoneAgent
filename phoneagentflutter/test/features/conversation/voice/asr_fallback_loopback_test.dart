import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/data/voice/asr_capture_session.dart';
import 'package:phone_agent/features/conversation/data/voice/fallback_voice_input_session.dart';
import 'package:phone_agent/features/conversation/data/voice/realtime_transcription_session.dart';
import 'package:phone_agent/features/conversation/data/voice/task_asr_session.dart';
import 'package:phone_agent/features/conversation/data/voice/task_voice_endpoint.dart';
import 'package:phone_agent/features/conversation/presentation/controller/voice_input_controller.dart';
import 'package:phone_agent/features/conversation/presentation/controller/voice_input_state.dart';
import '../../../core/audio/pcm_capture_fake.dart';
import 'voice_input_fake.dart';

void main() {
  test(
    'real loopback primary error -> backend PCM -> one gesture submission',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final peers = <WebSocket>[];
      final requests = <Uri>[];
      final primaryControls = <String>[], fallbackControls = <Object>[];
      final fallbackClosed = Completer<void>();
      server.listen((request) async {
        requests.add(request.uri);
        final socket = await WebSocketTransformer.upgrade(request);
        peers.add(socket);
        final primary = request.uri.path.endsWith('/asr');
        socket.listen(
          (data) {
            if (primary) {
              if (data is String) {
                primaryControls.add(
                  (jsonDecode(data) as Map)['type'] as String,
                );
              } else {
                socket.add('{"type":"final","text":"明天"}');
                socket.add('{"type":"partial","text":"错误片段"}');
                socket.add('{"type":"error","message":"synthetic"}');
              }
            } else {
              fallbackControls.add(data);
              if (data is List<int>) {
                socket.add('{"type":"final","text":"明天下午"}');
              }
            }
          },
          onDone: () {
            if (!primary && !fallbackClosed.isCompleted) {
              fallbackClosed.complete();
            }
          },
        );
        socket.add('{"type":"ready"}');
      });
      final first = PcmCaptureFake(), second = PcmCaptureFake();
      final submitted = <String>[];
      var created = 0;
      final base = Uri.parse(
        'http://127.0.0.1:${server.port}/aiassistant-api/',
      );
      final session = FallbackVoiceInputSession(
        primary: AsrCaptureSession(capture: first, asr: TaskAsrSession()),
        createFallback: () {
          expect(first.stops, greaterThan(0));
          created++;
          return AsrCaptureSession(
            capture: second,
            asr: RealtimeTranscriptionSession(),
          );
        },
        fallbackEndpoint: TaskVoiceEndpoint.transcription(
          base,
          userId: 'synthetic-account',
        ),
        isCurrent: () => true,
      );
      final input = VoiceInputController(
        createSession: () => session,
        permissions: InputPermissionFake(),
        endpoint: TaskVoiceEndpoint.asr(base, 'zh-CN'),
        isCurrent: () => true,
        canSubmit: () => true,
        submit: (text) {
          submitted.add(text);
          return true;
        },
      );
      addTearDown(() async {
        input.dispose();
        await session.cancel();
        first.frame(null);
        second.frame(null);
        for (final peer in peers) {
          await peer.close();
        }
        await server.close(force: true);
      });
      await input.press();
      await waitUntil(() => first.pendingRead != null);
      first.frame(Uint8List.fromList([1, 2]));
      await waitUntil(() => second.pendingRead != null);
      expect(created, 1);
      expect(input.state.phase, VoiceInputPhase.recording);
      expect(input.state.text, '明天');
      input.release();
      second.frame(Uint8List.fromList([3, 4]));
      await waitUntil(() => submitted.isNotEmpty);
      await fallbackClosed.future.timeout(const Duration(seconds: 3));
      expect(submitted, ['明天下午']);
      expect(primaryControls, ['start_capture', 'finish']);
      expect(fallbackControls.length, 1);
      expect(fallbackControls.single, [3, 4]);
      expect(
        requests.last.path,
        '/aiassistant-api/ws/assistant/realtime/transcription',
      );
      expect(requests.last.queryParameters, {
        'userId': 'synthetic-account',
        'languageCode': 'zh-CN',
      });
    },
  );
}

Future<void> waitUntil(bool Function() done) async {
  final deadline = DateTime.now().add(const Duration(seconds: 3));
  while (!done()) {
    if (DateTime.now().isAfter(deadline)) fail('Loopback condition timed out');
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}
