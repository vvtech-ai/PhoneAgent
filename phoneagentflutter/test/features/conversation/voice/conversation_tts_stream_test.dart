import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/audio/audio_playback_focus.dart';
import 'package:phone_agent/features/conversation/data/voice/conversation_tts_stream.dart';
import 'package:phone_agent/features/conversation/data/voice/task_tts_session.dart';
import 'package:phone_agent/features/conversation/data/voice/task_tts_connection_owner.dart';
import 'package:phone_agent/features/conversation/domain/voice/reply_speech_playback.dart';
import 'package:phone_agent/features/settings/domain/network_availability.dart';
import '../../../core/audio/pcm_output_fake.dart';
import 'voice_socket_fake.dart';

Future<void> tick() => Future<void>.delayed(Duration.zero);
void main() {
  test(
    'completed reply returns healthy synthesis session for next reply',
    () async {
      final socket = VoiceSocketFake();
      final shared = TaskTtsSession(connector: (_) async => socket);
      final owner = TaskTtsConnectionOwner(
        endpoint: Uri.parse('ws://synthetic.invalid/tts'),
        createSession: () => shared,
      );
      final first = ConversationTtsStream(
        endpoint: Uri.parse('ws://synthetic.invalid/tts'),
        createSession: () => shared,
        connectionOwner: owner,
        output: PcmOutputFake(),
        focus: AudioPlaybackFocus(),
        isCurrent: () => true,
        onChanged: () {},
      );
      first.enqueue('A');
      first.complete();
      await tick();
      socket.emit('{"type":"ready"}');
      socket.emit(Uint8List(2));
      socket.emit('{"type":"complete"}');
      await tick();
      await tick();
      expect(socket.closes, 0);
      expect(shared.closed, isFalse);
      await first.cancel();
      await shared.cancel();
      owner.dispose();
    },
  );
  late PcmOutputFake output;
  late AudioPlaybackFocus focus;
  late ConversationTtsStream stream;
  late List<VoiceSocketFake> sockets;
  bool alive = true;
  setUp(() {
    alive = true;
    sockets = [];
    output = PcmOutputFake();
    focus = AudioPlaybackFocus();
    stream = ConversationTtsStream(
      endpoint: Uri.parse('ws://synthetic.invalid/tts'),
      output: output,
      focus: focus,
      isCurrent: () => alive,
      onChanged: () {},
      createSession: () {
        return TaskTtsSession(
          connector: (_) async {
            final socket = VoiceSocketFake();
            sockets.add(socket);
            return socket;
          },
        );
      },
    );
  });
  tearDown(() async {
    output.failStop = false;
    await stream.cancel();
  });
  Future<void> audio(int index, {bool ready = true}) async {
    if (ready) sockets[index].emit('{"type":"ready"}');
    sockets[index].emit(Uint8List(24000));
    sockets[index].emit('{"type":"complete"}');
    await tick();
    await tick();
  }

  test(
    'initial and duplicate online snapshots do not cancel pending TTS',
    () async {
      await stream.cancel();
      final network = StreamController<NetworkAvailability>.broadcast(
        sync: true,
      );
      addTearDown(network.close);
      stream = ConversationTtsStream(
        endpoint: Uri.parse('ws://synthetic.invalid/tts'),
        output: output,
        focus: focus,
        isCurrent: () => alive,
        onChanged: () {},
        networkEvents: network.stream,
        createSession: () => TaskTtsSession(
          connector: (_) async {
            final socket = VoiceSocketFake();
            sockets.add(socket);
            return socket;
          },
        ),
      );
      stream.enqueue('测试稳定网络下的播报');
      await tick();
      network.add(NetworkAvailability.available);
      network.add(NetworkAvailability.available);
      network.add(NetworkAvailability.unknown);
      network.add(NetworkAvailability.available);
      await tick();
      expect(stream.failures, 0);
      expect(stream.synthesizing, isTrue);
      stream.complete();
      await audio(0);
      output.consume();
      await tick();
      await tick();
      expect(stream.phase, ReplySpeechPhase.completed);
    },
  );

  test('offline before audio retains current sentence until online', () async {
    await stream.cancel();
    final network = StreamController<NetworkAvailability>.broadcast(sync: true);
    addTearDown(network.close);
    stream = ConversationTtsStream(
      endpoint: Uri.parse('ws://synthetic.invalid/tts'),
      output: output,
      focus: focus,
      isCurrent: () => alive,
      onChanged: () {},
      networkEvents: network.stream,
      createSession: () => TaskTtsSession(
        connector: (_) async {
          final socket = VoiceSocketFake();
          sockets.add(socket);
          return socket;
        },
      ),
    );
    network.add(NetworkAvailability.available);
    stream.enqueue('测试真实断网');
    await tick();
    network.add(NetworkAvailability.unavailable);
    await tick();
    await tick();
    expect(stream.failures, 0);
    expect(stream.synthesizing, isTrue);
    expect(sockets, hasLength(1));
    network.add(NetworkAvailability.available);
    await tick();
    expect(sockets, hasLength(2));
    stream.complete();
    await audio(1);
    expect(jsonDecode(sockets[1].sent.first as String)['text'], '测试真实断网');
    expect(stream.failures, 0);
  });

  test(
    'selected speaker is fixed for all sentences; cancelled pending read cannot connect',
    () async {
      await stream.cancel();
      final choice = Completer<String>();
      stream = ConversationTtsStream(
        endpoint: Uri.parse('ws://synthetic.invalid/tts'),
        speaker: choice.future,
        output: output,
        focus: focus,
        isCurrent: () => alive,
        onChanged: () {},
        createSession: () {
          return TaskTtsSession(
            connector: (_) async {
              final socket = VoiceSocketFake();
              sockets.add(socket);
              return socket;
            },
          );
        },
      );
      stream.enqueue('第一句。');
      stream.enqueue('第二句。');
      stream.complete();
      await tick();
      expect(sockets, isEmpty);
      choice.complete('Andre');
      await tick();
      await tick();
      await audio(0);
      await audio(0, ready: false);
      expect(sockets, hasLength(1));
      expect(
        sockets.single.sent
            .whereType<String>()
            .map(jsonDecode)
            .where((value) => value['type'] == 'synthesize')
            .map((value) => value['speaker']),
        everyElement('Andre'),
      );
      output.consume();
      await tick();
      await stream.cancel();
    },
  );

  test('cancel before preference resolves never opens a socket', () async {
    await stream.cancel();
    final choice = Completer<String>();
    var connects = 0;
    stream = ConversationTtsStream(
      endpoint: Uri.parse('ws://synthetic.invalid/tts'),
      speaker: choice.future,
      output: output,
      focus: focus,
      isCurrent: () => alive,
      onChanged: () {},
      createSession: () => TaskTtsSession(
        connector: (_) async {
          connects++;
          return VoiceSocketFake();
        },
      ),
    );
    stream.enqueue('取消的句子');
    await stream.cancel();
    choice.complete('Andre');
    await tick();
    expect(connects, 0);
  });

  test(
    'serial synthesis runs ahead; one output, guard and tail per reply',
    () async {
      stream.enqueue('**第一句。**');
      stream.enqueue('第二句。');
      stream.complete();
      await tick();
      expect(sockets, hasLength(1));
      await audio(0);
      expect(sockets, hasLength(1));
      expect(
        output.pending,
        isNotEmpty,
      ); // No consumption needed for second synthesis.
      final requests = sockets.single.sent
          .whereType<String>()
          .map(jsonDecode)
          .toList();
      expect(requests.first['text'], '第一句。');
      await audio(0, ready: false);
      final completedRequests = sockets.single.sent
          .whereType<String>()
          .map(jsonDecode)
          .where((value) => value['type'] == 'synthesize')
          .toList();
      expect(completedRequests, hasLength(2));
      for (final request in completedRequests) {
        expect(request['speaker'], 'Maia');
        expect(
          request.containsKey('purpose'),
          isFalse,
          reason:
              'Task replies must not bypass the server selection as previews',
        );
      }
      expect(stream.phase, ReplySpeechPhase.draining);
      expect(stream.queuedBytes, 15360 + 48000 + 2880);
      expect(output.starts, 1);
      output.consume();
      await tick();
      await tick();
      expect(stream.phase, ReplySpeechPhase.completed);
      expect(focus.active, isNull);
    },
  );
  test(
    'complete between source completion and scheduled next seals once',
    () async {
      stream.enqueue('句子');
      await tick();
      sockets[0].emit('{"type":"ready"}');
      sockets[0].emit(Uint8List(24000));
      sockets[0].emit('{"type":"complete"}');
      stream.complete();
      stream.complete();
      await tick();
      await tick();
      output.consume();
      await tick();
      expect(stream.phase, ReplySpeechPhase.completed);
      expect(output.starts, 1);
    },
  );
  test(
    'provider failure advances pending sentence and remains observable',
    () async {
      stream.enqueue('第一句');
      stream.enqueue('第二句');
      stream.complete();
      await tick();
      sockets[0].emit('{"type":"error","message":"private"}');
      await tick();
      await tick();
      await tick();
      await tick();
      await tick();
      await tick();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(stream.failures, 1);
      expect(sockets, hasLength(2));
      await audio(1);
      output.consume();
      await tick();
      await tick();
      expect(stream.phase, ReplySpeechPhase.completed);
      expect(stream.failures, 1);
    },
  );
  test('cancel suppresses queued sentences and late audio', () async {
    stream.enqueue('第一句');
    stream.enqueue('第二句');
    await tick();
    sockets[0].emit('{"type":"ready"}');
    sockets[0].emit(Uint8List(24000));
    await stream.cancel();
    await tick();
    expect(sockets, hasLength(1));
    expect(stream.queuedBytes, 0);
    expect(stream.phase, ReplySpeechPhase.cancelled);
    expect(focus.active, isNull);
  });
  test(
    'device failure does not start queued synthesis or fake release',
    () async {
      stream.enqueue('第一句');
      stream.enqueue('第二句');
      await tick();
      sockets[0].emit('{"type":"ready"}');
      sockets[0].emit(Uint8List(24000));
      await tick();
      output.failStop = true;
      output.fail();
      await tick();
      await tick();
      expect(stream.phase, ReplySpeechPhase.failed);
      expect(focus.active, isNotNull);
      expect(sockets, hasLength(1));
      output.failStop = false;
      await stream.cancel();
      expect(focus.active, isNull);
    },
  );
  test(
    'changed owner and oversized pending text cannot send new synthesis',
    () async {
      stream.enqueue('第一句');
      await tick();
      alive = false;
      sockets[0].emit('{"type":"ready"}');
      await tick();
      await tick();
      expect(stream.phase, ReplySpeechPhase.cancelled);
      expect(stream.enqueue('已结束后的结果'), isFalse);
    },
  );
  test(
    'empty cleaned text does not connect and complete releases no device',
    () async {
      expect(stream.enqueue('```hidden```'), isFalse);
      stream.complete();
      await tick();
      expect(sockets, isEmpty);
      expect(output.starts, 0);
      expect(stream.phase, ReplySpeechPhase.completed);
    },
  );
}
