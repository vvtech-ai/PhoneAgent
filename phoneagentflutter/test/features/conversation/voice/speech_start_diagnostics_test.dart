import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/audio/audio_playback_focus.dart';
import 'package:phone_agent/core/audio/diagnosed_pcm_output.dart';
import 'package:phone_agent/core/diagnostics/diagnostic_event.dart';
import 'package:phone_agent/core/diagnostics/media_diagnostics.dart';
import 'package:phone_agent/features/conversation/data/voice/conversation_tts_stream.dart';
import 'package:phone_agent/features/conversation/data/voice/task_tts_session.dart';
import 'package:phone_agent/features/conversation/data/voice/preview_voice_input.dart';
import 'package:phone_agent/features/conversation/domain/agent_protocol.dart';
import 'package:phone_agent/features/conversation/domain/voice/reply_speech_start.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_controller.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_state.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_speech_controller.dart';
import '../../../core/audio/pcm_output_fake.dart';
import 'voice_socket_fake.dart';
import 'conversation_speech_controller_test.dart' show SpeechFake;

Future<void> tick() => Future<void>.delayed(Duration.zero);

class TurnGateway implements AgentGateway {
  final turns = <StreamController<AgentEvent>>[];
  @override
  AgentRun start(AgentCommand command) {
    final events = StreamController<AgentEvent>.broadcast();
    turns.add(events);
    return AgentRun(events.stream, () {});
  }
}

class ThrowingObserver extends SpeechFake implements ReplySpeechStartObserver {
  @override
  void observeSpeechStart(DateTime observedAt, int elapsedMs) =>
      throw StateError('private observer failure');
}

class Harness {
  Harness({this.failDiagnostics = false}) {
    speech = ConversationSpeechController(
      enabled: () => enabled,
      factory: (current, changed) {
        final index = outputs.length + 1;
        final trace = '00000000-0000-4000-8000-${'$index'.padLeft(12, '0')}';
        final diagnostic = MediaDiagnostics(
          record,
          DiagnosticMediaComponent.taskTts,
          traceId: trace,
        );
        final output = PcmOutputFake();
        outputs.add(output);
        return ConversationTtsStream(
          endpoint: Uri.parse('ws://synthetic.invalid/tts'),
          createSession: () => TaskTtsSession(
            diagnostics: diagnostic,
            connector: (_) async {
              final socket = VoiceSocketFake();
              sockets.add(socket);
              return socket;
            },
          ),
          output: DiagnosedPcmOutput(
            output,
            MediaDiagnostics(
              record,
              DiagnosticMediaComponent.pcmOutput,
              traceId: trace,
            ),
          ),
          diagnostics: diagnostic,
          focus: AudioPlaybackFocus(),
          isCurrent: current,
          onChanged: changed,
        );
      },
    );
  }
  final bool failDiagnostics;
  bool enabled = true;
  late final ConversationSpeechController speech;
  final events = <DiagnosticEvent>[];
  final outputs = <PcmOutputFake>[];
  final sockets = <VoiceSocketFake>[];
  void record(DiagnosticEvent event) {
    if (failDiagnostics) throw StateError('private diagnostic failure');
    events.add(event);
  }

  void text(String text) =>
      speech.accept(AgentEvent(AgentEventKind.text, text: text));
  List<DiagnosticEvent> get starts => events
      .where(
        (e) =>
            {'textObserved', 'sentenceEnqueued'}.contains(e.media?.stage.name),
      )
      .toList();
  Future<void> close() async {
    await speech.interrupt();
    speech.dispose();
    await tick();
  }
}

void main() {
  test(
    'live owner rejects late old stream after new turn and history is silent',
    () async {
      final h = Harness(), gateway = TurnGateway();
      final controller = ConversationController(
        entry: const ConversationEntry(sessionId: 'synthetic'),
        accountId: 'synthetic',
        gateway: gateway,
        history: PreviewVoiceInput(),
      )..speech = h.speech;
      addTearDown(() async {
        controller.dispose();
        for (final turn in gateway.turns) {
          await turn.close();
        }
      });
      await controller.restore();
      expect(h.events, isEmpty);
      expect(controller.send('第一轮输入'), isTrue);
      gateway.turns.first.add(
        const AgentEvent(AgentEventKind.text, text: '旧回复。'),
      );
      await tick();
      await tick();
      expect(h.starts, hasLength(2));
      final oldTrace = h.starts.first.traceId;
      controller.interruptReplyForInput();
      expect(controller.send('第二轮输入'), isTrue);
      final before = DateTime.now().toUtc();
      gateway.turns.first.add(
        const AgentEvent(AgentEventKind.text, text: '迟到。'),
      );
      gateway.turns.last.add(
        const AgentEvent(AgentEventKind.text, text: '当前回复。'),
      );
      await tick();
      await tick();
      expect(h.starts, hasLength(4));
      expect(h.starts[2].time.isBefore(before), isFalse);
      expect(h.starts.last.traceId, isNot(oldTrace));
      expect(h.sockets, hasLength(2));
      h.sockets.last.emit('{"type":"ready"}');
      await tick();
      expect(jsonDecode(h.sockets.last.sent.single as String)['text'], '当前回复。');
    },
  );

  test('observer exception cannot consume the synthesis handoff', () {
    final player = ThrowingObserver();
    final speech = ConversationSpeechController(
      factory: (_, __) => player,
      enabled: () => true,
    );
    addTearDown(speech.dispose);
    speech.accept(const AgentEvent(AgentEventKind.text, text: '仍应合成。'));
    expect(player.sentences, ['仍应合成。']);
  });

  test(
    'first text keeps original time and shares actual TTS and PCM trace once',
    () async {
      final h = Harness();
      addTearDown(h.close);
      final before = DateTime.now().toUtc();
      h.text('第一');
      final after = DateTime.now().toUtc();
      expect(h.outputs, isEmpty);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      h.text('句。第二句。');
      await tick();
      expect(h.starts.map((e) => e.media!.stage.name), [
        'textObserved',
        'sentenceEnqueued',
      ]);
      expect(h.starts.first.time.isBefore(before), isFalse);
      expect(h.starts.first.time.isAfter(after), isFalse);
      expect(h.starts.last.elapsedMs, greaterThanOrEqualTo(20));
      expect(h.sockets, hasLength(1));
      expect(h.sockets.single.sent, isEmpty); // Still awaits ready.
      h.sockets.single.emit('{"type":"ready"}');
      await tick();
      expect(
        jsonDecode(h.sockets.single.sent.single as String)['text'],
        '第一句。',
      );
      h.sockets.single.emit(Uint8List(24000));
      await tick();
      await tick();
      h.outputs.single.consume();
      await tick();
      expect(h.events.map((e) => e.traceId).toSet(), {h.starts.first.traceId});
      final stages = h.events.map((e) => e.media!.stage.name).toList();
      expect(
        stages.indexOf('textObserved'),
        lessThan(stages.indexOf('sentenceEnqueued')),
      );
      expect(
        stages.indexOf('sentenceEnqueued'),
        lessThan(stages.indexOf('connect')),
      );
      expect(stages.indexOf('send'), lessThan(stages.indexOf('receive')));
      expect(stages, contains('play'));
      h.sockets.single.emit('{"type":"complete"}');
      await tick();
      await tick();
      final requests = h.sockets.single.sent
          .map((v) => jsonDecode(v as String))
          .where((v) => v['type'] == 'synthesize')
          .toList();
      expect(requests.map((v) => v['text']), ['第一句。', '第二句。']);
      expect(h.starts, hasLength(2));
      final encoded = jsonEncode(h.events.map((e) => e.toJson()).toList());
      expect(encoded, isNot(contains('第一')));
      expect(encoded, isNot(contains('第二')));
    },
  );

  test(
    'cancelled buffered text and disabled or restored text cannot seed next turn',
    () async {
      final h = Harness();
      addTearDown(h.close);
      h.speech.speakOpening('历史正文。', restored: true);
      h.text('');
      h.text('取消前尚未分句');
      await h.speech.interrupt();
      h.text('迟到旧正文。');
      expect(h.starts, isEmpty);
      expect(h.outputs, isEmpty);
      h.speech.begin();
      h.enabled = false;
      h.text('关闭播报。');
      h.enabled = true;
      final before = DateTime.now().toUtc();
      h.text('新轮正文。');
      await tick();
      expect(h.starts, hasLength(2));
      expect(h.starts.first.time.isBefore(before), isFalse);
      final trace = h.starts.first.traceId;
      await h.speech.interrupt();
      h.speech.begin();
      h.text('第三轮正文。');
      await tick();
      expect(h.starts, hasLength(4));
      expect(h.starts.last.traceId, isNot(trace));
    },
  );

  test(
    'no speakable markdown and diagnostic failure preserve audio actions',
    () async {
      final empty = Harness();
      addTearDown(empty.close);
      empty.text('```hidden```');
      empty.speech.finish();
      await tick();
      expect(empty.starts, isEmpty);
      expect(empty.sockets, isEmpty);

      final h = Harness(failDiagnostics: true);
      addTearDown(h.close);
      h.text('仍应播报。');
      await tick();
      h.sockets.single.emit('{"type":"ready"}');
      await tick();
      expect(
        jsonDecode(h.sockets.single.sent.single as String)['text'],
        '仍应播报。',
      );
      h.sockets.single.emit(Uint8List(24000));
      await tick();
      await tick();
      expect(h.outputs.single.starts, 1);
      expect(h.outputs.single.chunks, isNotEmpty);
    },
  );
}
