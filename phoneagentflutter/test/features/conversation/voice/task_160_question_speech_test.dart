import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/agent_protocol.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_speech_controller.dart';
import 'conversation_speech_controller_test.dart' show SpeechFake;

AgentEvent question(String id, {String session = 'session'}) => AgentEvent(
  AgentEventKind.signal,
  sessionId: session,
  payload: {
    'type': 'ASK_USER',
    'pendingToolCallId': id,
    'questions': {'title': '请确认以上任务理解', 'items': <Object>[]},
  },
);

class _FlakySpeech extends SpeechFake {
  bool fail = true;
  @override
  bool enqueue(String text) {
    if (fail) {
      fail = false;
      throw StateError('synthetic handoff failure');
    }
    return super.enqueue(text);
  }
}

void main() {
  test(
    'same pending question is spoken once per session, including later turns',
    () {
      final player = SpeechFake();
      final speech = ConversationSpeechController(
        factory: (_, __) => player,
        enabled: () => true,
      );
      addTearDown(speech.dispose);
      speech.begin(sessionId: 'session');
      speech.accept(question('q'));
      speech.accept(question('q'));
      speech.accept(question('q', session: ''));
      speech.begin(sessionId: 'session');
      speech.accept(question('q'));
      expect(player.sentences, ['请确认以上任务理解']);
      speech.accept(question('new'));
      expect(player.sentences, hasLength(2));
      speech.begin(sessionId: 'other');
      speech.accept(question('q', session: 'other'));
      expect(player.sentences, hasLength(3));
    },
  );
  test('failed handoff does not consume question identity and can retry', () {
    final player = _FlakySpeech();
    final speech = ConversationSpeechController(
      factory: (_, __) => player,
      enabled: () => true,
    );
    addTearDown(speech.dispose);
    speech.begin(sessionId: 'session');
    expect(() => speech.accept(question('q')), returnsNormally);
    speech.accept(question('q'));
    speech.accept(question('q'));
    expect(player.sentences, ['请确认以上任务理解']);
  });
  test('muted question is not consumed and resume alone never speaks', () {
    bool enabled = false;
    final player = SpeechFake();
    final speech = ConversationSpeechController(
      factory: (_, __) => player,
      enabled: () => enabled,
    );
    addTearDown(speech.dispose);
    speech.begin(sessionId: 'session');
    speech.accept(question('q'));
    enabled = true;
    expect(player.sentences, isEmpty);
    speech.accept(question('q'));
    speech.accept(question('q'));
    expect(player.sentences, ['请确认以上任务理解']);
  });
}
