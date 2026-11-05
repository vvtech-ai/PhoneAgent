import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/data/stream/agent_event_decoder.dart';
import 'package:phone_agent/features/conversation/data/stream/sse_frame_decoder.dart';
import 'package:phone_agent/features/conversation/data/voice/preview_voice_input.dart';
import 'package:phone_agent/features/conversation/domain/agent_protocol.dart';
import 'package:phone_agent/features/conversation/domain/history/conversation_history.dart';
import 'package:phone_agent/features/conversation/domain/history/ledger_event.dart';
import 'package:phone_agent/features/conversation/domain/membership_denial_reply.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_controller.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_state.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_speech_controller.dart';
import 'conversation_speech_controller_test.dart' show SpeechFake;

class _Gateway implements AgentGateway {
  final events = StreamController<AgentEvent>();
  int starts = 0;
  @override
  AgentRun start(AgentCommand command) {
    starts++;
    return AgentRun(events.stream, () {});
  }
}

class _DeniedHistory implements ConversationHistoryRepository {
  @override
  Future<RestoredConversation> restore(String sessionId) async =>
      RestoredConversation(
        ConversationDetail(
          sessionId: sessionId,
          title: '合成会议邀请',
          status: 'EXECUTION_ERROR',
        ),
        ledger: LedgerSnapshot(
          sessionId,
          1,
          const LedgerProjection(
            status: 'EXECUTION_ERROR',
            continuable: true,
            pendingRestorable: false,
            migrationStatus: 'CURRENT',
            projectedThrough: 1,
          ),
          [
            LedgerEvent(
              eventId: 'denied',
              sessionId: sessionId,
              sequence: 1,
              type: 'RUN_FAILED',
              schemaVersion: 1,
              commandId: 'original-command',
              payload: {
                'reason': 'BATCH_CONCURRENCY_LIMIT',
                'stage': 'tool',
                'retryable': false,
              },
            ),
          ],
        ),
      );
}

void main() {
  test(
    'reopening denied task restores its reply without speaking or dialing',
    () async {
      final gateway = _Gateway();
      final player = SpeechFake();
      final controller = ConversationController(
        entry: const ConversationEntry(sessionId: 'session', restore: true),
        accountId: 'synthetic',
        gateway: gateway,
        history: _DeniedHistory(),
      );
      controller.speech = ConversationSpeechController(
        factory: (_, __) => player,
        enabled: () => controller.isOpen,
      );
      addTearDown(() {
        controller.dispose();
        gateway.events.close();
      });
      await controller.restore();
      await controller.restore();
      expect(
        controller.state.messages.where(
          (m) =>
              m.text ==
              MembershipDenialReply.message('BATCH_CONCURRENCY_LIMIT'),
        ),
        hasLength(1),
      );
      expect(controller.state.messages.single.transient, isFalse);
      expect(player.sentences, isEmpty);
      expect(gateway.starts, 0);
    },
  );
  test(
    'membership denial creates one assistant reply and narrates once',
    () async {
      final gateway = _Gateway();
      final player = SpeechFake();
      var accountCurrent = true;
      final controller = ConversationController(
        entry: const ConversationEntry(sessionId: 'session'),
        accountId: 'synthetic',
        gateway: gateway,
        history: PreviewVoiceInput(),
        accountIsCurrent: () => accountCurrent,
      );
      controller.speech = ConversationSpeechController(
        factory: (_, __) => player,
        enabled: () => controller.isOpen,
      );
      addTearDown(() {
        controller.dispose();
        gateway.events.close();
      });
      controller.send('拨打联系人');
      final denial = const AgentEventDecoder().decode(
        SseFrame(
          'task_failed',
          jsonEncode({
            'sessionId': 'session',
            'displayMessage': '当前会员批量联系人或并发上限不足，请检查批量外呼权益',
            'data': {
              'errorCode': 'BATCH_ENTITLEMENT_LIMIT',
              'recoveryAction': 'CHECK_MEMBERSHIP',
              'retryable': false,
              'category': 'ENTITLEMENT',
            },
          }),
        ),
      );
      gateway.events.add(denial);
      gateway.events.add(denial);
      gateway.events.add(
        AgentEvent(
          AgentEventKind.finalResponse,
          sessionId: 'session',
          text: denial.text,
          payload: const {'type': 'TEXT_REPLY'},
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(player.sentences, [denial.text]);
      expect(
        controller.state.messages.where((m) => m.text == denial.text),
        hasLength(1),
      );
      accountCurrent = false;
      gateway.events.add(denial);
      await Future<void>.delayed(Duration.zero);
      expect(player.sentences, [denial.text]);
      controller.close();
      gateway.events.add(denial);
      await Future<void>.delayed(Duration.zero);
      expect(player.sentences, [denial.text]);
    },
  );
}
