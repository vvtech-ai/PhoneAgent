import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/contacts/data/preview_contact_agent.dart';
import 'package:phone_agent/features/conversation/domain/agent_protocol.dart';
import 'package:phone_agent/features/conversation/domain/history/conversation_history.dart';
import 'package:phone_agent/features/conversation/domain/history/ledger_event.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_controller.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_state.dart';

void main() {
  for (final skill in [
    'restaurant_booking',
    'meeting_notification',
    'business_event_invitation',
  ]) {
    test(
      '$skill first turn carries configured opening and hidden contact once',
      () async {
        final gateway = _Gateway();
        final controller = _controller(skill, gateway);
        addTearDown(controller.dispose);
        expect(controller.send(' '), isFalse);
        expect(gateway.commands, isEmpty);
        expect(controller.send('合成用户需求'), isTrue);
        await Future<void>.delayed(Duration.zero);
        final first = gateway.commands.single.toJson();
        expect(first['initialSkillId'], skill);
        expect(first['initialOpening'], '合成配置开场');
        expect(first['selectedContact'], {
          'source': 'CONTACT_DETAIL',
          'name': '合成联系人',
          'phone': '+12025550101',
        });
        expect(first['message'], '合成用户需求');
        expect(first['actionId'], isNull);
        expect(controller.send('补充合成事实'), isTrue);
        final next = gateway.commands.last.toJson();
        expect(next.containsKey('initialSkillId'), isFalse);
        expect(next.containsKey('initialOpening'), isFalse);
        expect(next.containsKey('selectedContact'), isFalse);
      },
    );

    test(
      '$skill restored conversation does not re-arm initial context',
      () async {
        final gateway = _Gateway();
        final controller = _controller(skill, gateway);
        addTearDown(controller.dispose);
        await controller.restore();
        expect(gateway.commands, isEmpty);
        expect(controller.send('补充合成事实'), isTrue);
        final command = gateway.commands.single.toJson();
        expect(command.containsKey('initialSkillId'), isFalse);
        expect(command.containsKey('initialOpening'), isFalse);
        expect(command.containsKey('selectedContact'), isFalse);
        expect(command['actionId'], isNull);
      },
    );
  }
}

ConversationController _controller(String skill, AgentGateway gateway) =>
    ConversationController(
      entry: ConversationEntry(
        sessionId: 'synthetic',
        skillId: skill,
        opening: '合成配置开场',
        selectedContact: const SelectedContactContext(
          name: '合成联系人',
          phone: '+12025550101',
        ),
      ),
      accountId: 'synthetic',
      gateway: gateway,
      history: _History(),
    );

class _Gateway implements AgentGateway {
  final commands = <AgentCommand>[];
  @override
  AgentRun start(AgentCommand command) {
    commands.add(command);
    return AgentRun(Stream.value(const AgentEvent(AgentEventKind.done)), () {});
  }
}

class _History extends PreviewContactAgent {
  @override
  Future<RestoredConversation> restore(String sessionId) async =>
      RestoredConversation(
        ConversationDetail(
          sessionId: sessionId,
          title: '合成任务',
          status: 'ACTIVE',
        ),
        ledger: LedgerSnapshot(
          sessionId,
          0,
          const LedgerProjection(
            status: 'ACTIVE',
            continuable: true,
            pendingRestorable: false,
            migrationStatus: 'NATIVE',
            projectedThrough: 0,
          ),
          const [],
        ),
      );
}
