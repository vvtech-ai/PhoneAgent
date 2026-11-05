import 'dart:typed_data';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/audio/audio_playback_focus.dart';
import 'package:phone_agent/features/conversation/data/voice/conversation_tts_stream.dart';
import 'package:phone_agent/features/conversation/data/voice/task_tts_session.dart';
import 'package:phone_agent/features/conversation/domain/agent_protocol.dart';
import 'package:phone_agent/features/conversation/domain/voice/reply_speech_playback.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_speech_controller.dart';
import '../../../core/audio/pcm_output_fake.dart';
import 'voice_socket_fake.dart';

Future<void> tick() => Future<void>.delayed(Duration.zero);

void main() {
  late ConversationSpeechController speech;
  late List<ConversationTtsStream> streams;
  late List<VoiceSocketFake> sockets;
  late AudioPlaybackFocus focus;
  late PcmOutputFake output;
  setUp(() {
    streams = [];
    sockets = [];
    focus = AudioPlaybackFocus();
    output = PcmOutputFake();
    speech = ConversationSpeechController(
      enabled: () => true,
      factory: (current, changed) {
        final stream = ConversationTtsStream(
          endpoint: Uri.parse('ws://synthetic.invalid/tts'),
          output: output,
          focus: focus,
          isCurrent: current,
          onChanged: changed,
          createSession: () => TaskTtsSession(
            connector: (_) async {
              final socket = VoiceSocketFake(closeMessagesOnClose: false);
              sockets.add(socket);
              return socket;
            },
          ),
        );
        streams.add(stream);
        return stream;
      },
    );
  });
  tearDown(() async {
    output.failStop = false;
    speech.dispose();
    for (final stream in streams) {
      await stream.cancel();
    }
    for (final socket in sockets) {
      await socket.input.close();
    }
  });
  Future<void> begin() async {
    speech.begin();
    speech.accept(const AgentEvent(AgentEventKind.text, text: '正在播报。'));
    await tick();
    sockets.last.emit('{"type":"ready"}');
    await tick();
  }

  for (final state in [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
    AppLifecycleState.detached,
  ]) {
    for (final hasAudio in [false, true]) {
      test(
        '$state during ${hasAudio ? 'audio' : 'synthesis'} cancels without failure or replay',
        () async {
          await begin();
          if (hasAudio) {
            sockets.single.emit(Uint8List(24000));
            await tick();
          }
          final stream = streams.single;
          stream.handleAppLifecycle(state);
          await tick();
          await tick();
          expect(stream.failures, 0);
          expect(stream.phase, ReplySpeechPhase.cancelled);
          expect(speech.status, '播报已暂停，可继续交流');
          expect(stream.synthesizing, isFalse);
          expect(focus.active, isNull);
          sockets.single.emit(Uint8List(24000));
          sockets.single.emit('{"type":"error"}');
          stream.handleAppLifecycle(AppLifecycleState.resumed);
          await tick();
          expect(stream.failures, 0);
          expect(output.pending, isEmpty);
          expect(sockets, hasLength(1));
          await begin();
          expect(speech.status, '正在播报…');
          expect(streams.last.failures, 0);
          expect(sockets, hasLength(2));
        },
      );
    }
  }

  test(
    'focus interruption pauses without counting a synthesis failure',
    () async {
      await begin();
      sockets.single.emit(Uint8List(24000));
      await tick();
      expect(focus.active, isNotNull);
      await focus.stopAll();
      await tick();
      expect(streams.single.phase, ReplySpeechPhase.cancelled);
      expect(streams.single.failures, 0);
      expect(speech.status, '播报已暂停，可继续交流');
      expect(focus.active, isNull);
    },
  );

  test(
    'provider failure remains failure after normal lifecycle cancellation',
    () async {
      await begin();
      sockets.single.emit('{"type":"error","message":"synthetic"}');
      await tick();
      expect(speech.status, '播报失败，可继续文字交互');
      streams.single.handleAppLifecycle(AppLifecycleState.inactive);
      await tick();
      expect(streams.single.failures, 1);
      expect(speech.status, '播报失败，可继续文字交互');
    },
  );

  test(
    'transport failure after audio remains failure after explicit pause',
    () async {
      await begin();
      sockets.single.emit(Uint8List(24000));
      await tick();
      sockets.single.input.addError(StateError('synthetic transport failure'));
      await tick();
      expect(speech.status, '播报失败，可继续文字交互');
      await speech.pause();
      expect(streams.single.failures, 1);
      expect(speech.status, '播报失败，可继续文字交互');
      expect(focus.active, isNull);
    },
  );

  test(
    'output shutdown failure after normal pause stays failed until real release',
    () async {
      await begin();
      sockets.single.emit(Uint8List(24000));
      await tick();
      output.failStop = true;
      await speech.pause();
      expect(streams.single.phase, ReplySpeechPhase.failed);
      expect(speech.status, '播报失败，可继续文字交互');
      expect(focus.active, isNotNull);
      output.failStop = false;
      await speech.pause();
      expect(focus.active, isNull);
      expect(speech.status, '播报失败，可继续文字交互');
    },
  );
}
