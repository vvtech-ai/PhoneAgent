import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/agent_protocol.dart';
import 'package:phone_agent/features/conversation/domain/receipts/batch_progress_tracker.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_message_store.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_outcome_flow.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_speech_controller.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_state.dart';
import '../../../tool/previews/shell_conversation_fakes.dart';
import 'voice/conversation_speech_controller_test.dart' show SpeechFake;

void main() {
  test('old completion cannot seal current permission reply speech', () async {
    final players = <SpeechFake>[];
    final speech = ConversationSpeechController(
      enabled: () => true,
      factory: (_, __) {
        final player = SpeechFake();
        players.add(player);
        return player;
      },
    )..begin(sessionId: 's');
    addTearDown(speech.dispose);
    var state = const ConversationState(
      entry: ConversationEntry(sessionId: 's'),
      phase: ConversationPhase.sending,
    );
    var completed = 0;
    final flow = ConversationOutcomeFlow(
      messages: ConversationMessageStore(),
      history: OfflineHistory(),
      batch: BatchProgressTracker(),
      current: (run) => run == 2,
      generation: () => 2,
      read: () => state,
      write: (value) => state = value,
      publish: () {},
      speech: () => speech,
      batchFinished: () {},
    );
    speech.accept(const AgentEvent(AgentEventKind.text, text: '续接第一句。'));
    await flow.complete(1, () => ++completed);
    speech.accept(const AgentEvent(AgentEventKind.text, text: '续接第二句。'));
    expect(players.single.sentences, ['续接第一句。', '续接第二句。']);
    expect(completed, 0);
    expect(state.phase, ConversationPhase.sending);
    await flow.complete(2, () => ++completed);
    expect(completed, 1);
    expect(state.phase, ConversationPhase.ready);
  });
}
