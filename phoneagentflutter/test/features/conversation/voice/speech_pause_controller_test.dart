import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/agent_protocol.dart';
import 'package:phone_agent/features/conversation/domain/voice/reply_speech_playback.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_speech_controller.dart';
import 'conversation_speech_controller_test.dart' show SpeechFake;

void main() {
  late ConversationSpeechController speech;
  late List<SpeechFake> players;
  late List<void Function()> callbacks;
  setUp(() {
    players = [];
    callbacks = [];
    speech = ConversationSpeechController(
      enabled: () => true,
      factory: (_, changed) {
        callbacks.add(changed);
        final player = SpeechFake()..synthesizing = true;
        players.add(player);
        return player;
      },
    );
  });
  tearDown(() => speech.dispose());
  void begin() {
    speech.begin();
    speech.accept(const AgentEvent(AgentEventKind.text, text: '当前播报。'));
  }

  test('normal cancellation exposes pause and interrupt clears it', () async {
    begin();
    await players.single.cancel();
    callbacks.single();
    expect(speech.status, '播报已暂停，可继续交流');
    await speech.interrupt();
    expect(speech.status, isEmpty);
  });
  test('old cancellation and failure cannot pollute a new turn', () async {
    begin();
    await players.single.cancel();
    callbacks.single();
    expect(speech.status, '播报已暂停，可继续交流');
    begin();
    players.first.failures = 1;
    callbacks.first();
    expect(speech.status, '正在播报…');
    expect(players.last.sentences, ['当前播报。']);
  });
  test(
    'real output failure remains failed after stop overwrites player phase',
    () async {
      begin();
      players.single.phase = ReplySpeechPhase.failed;
      callbacks.single();
      expect(speech.status, '播报失败，可继续文字交互');
      await speech.interrupt();
      expect(speech.status, '播报失败，可继续文字交互');
      begin();
      expect(speech.status, '正在播报…');
    },
  );
  test(
    'explicit pause preserves a real failure and never invents idle playback',
    () async {
      await speech.pause();
      expect(speech.status, isEmpty);
      expect(players, isEmpty);
      begin();
      players.single.failures = 1;
      callbacks.single();
      await speech.pause();
      expect(speech.status, '播报失败，可继续文字交互');
      speech.accept(const AgentEvent(AgentEventKind.text, text: '不重播。'));
      expect(players.single.sentences, ['当前播报。']);
    },
  );
}
