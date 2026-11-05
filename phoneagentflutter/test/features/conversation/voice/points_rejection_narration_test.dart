import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/agent_protocol.dart';
import 'package:phone_agent/features/conversation/domain/conversation_messages.dart';
import 'package:phone_agent/features/conversation/domain/voice/committed_reply_narration.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_speech_controller.dart';

import 'committed_reply_narration_test.dart' show reply;
import 'conversation_speech_controller_test.dart' show SpeechFake;

const _notice = '积分不足，本次未发起外呼。';
AgentEvent _rejected(String command, bool batch, {bool wire = true}) =>
    AgentEvent(
      AgentEventKind.finalResponse,
      sessionId: 's',
      text: _notice,
      payload: {
        if (wire) 'commandId': command,
        'type': batch ? 'BATCH_CALL_RESULT' : 'CALL_RESULT',
        if (batch)
          'batchCallResult': {
            'status': 'FAILED',
            'resultCode': 'POINTS_INSUFFICIENT_BALANCE',
          }
        else
          'callResult': {
            'status': 'FAILED',
            'metadata': {'resultCode': 'POINTS_INSUFFICIENT_BALANCE'},
          },
      },
    );

void main() {
  for (final batch in [false, true]) {
    test(
      'active command fallback narrates native envelopes once per attempt, batch=$batch',
      () {
        final players = <SpeechFake>[];
        final speech = ConversationSpeechController(
          enabled: () => true,
          factory: (_, _) {
            final player = SpeechFake();
            players.add(player);
            return player;
          },
        );
        addTearDown(speech.dispose);
        for (var turn = 1; turn <= 2; turn++) {
          final command = 'command-$turn';
          speech.begin(sessionId: 's');
          final fact = reply(
            id: 'native-reply-$turn',
            sequence: turn,
            reason: batch ? 'batch_call_result' : 'call_result',
            text: _notice,
          );
          final event = _rejected(command, batch, wire: false);
          speech.results.committed(fact);
          speech.accept(event, commandId: command);
          speech.project([fact], ConversationMessages.project([fact]));
          speech.accept(event, commandId: command);
          speech.project([fact], ConversationMessages.project([fact]));
          expect(
            players.expand((p) => p.sentences),
            List.filled(turn, _notice),
          );
        }
      },
    );
    test(
      'independent commands narrate identical pre-dial rejection once each, batch=$batch',
      () {
        final join = CommittedReplyNarration();
        for (var turn = 1; turn <= 2; turn++) {
          join.begin('s');
          final fact = reply(
            id: 'reply-$turn',
            sequence: turn,
            reason: batch ? 'batch_call_result' : 'call_result',
            text: _notice,
          );
          final rejected = _rejected('command-$turn', batch);
          join.committed(fact);
          join.terminal(rejected);
          join.project([fact], ConversationMessages.project([fact]));
          expect(join.take(), _notice, reason: 'independent command $turn');
          join.terminal(rejected);
          expect(join.take(), isNull);
        }
      },
    );

    test(
      'speech plays both independent command rejections without replay, batch=$batch',
      () {
        final players = <SpeechFake>[];
        final speech = ConversationSpeechController(
          enabled: () => true,
          factory: (_, _) {
            final player = SpeechFake();
            players.add(player);
            return player;
          },
        );
        addTearDown(speech.dispose);
        for (var turn = 1; turn <= 2; turn++) {
          speech.begin(sessionId: 's');
          final fact = reply(
            id: 'reply-$turn',
            sequence: turn,
            reason: batch ? 'batch_call_result' : 'call_result',
            text: _notice,
          );
          final rejected = _rejected('command-$turn', batch);
          speech.results.committed(fact);
          speech.accept(rejected);
          speech.project([fact], ConversationMessages.project([fact]));
          speech.accept(rejected);
          speech.project([fact], ConversationMessages.project([fact]));
          expect(
            players.expand((p) => p.sentences),
            List.filled(turn, _notice),
          );
        }
      },
    );
  }
}
