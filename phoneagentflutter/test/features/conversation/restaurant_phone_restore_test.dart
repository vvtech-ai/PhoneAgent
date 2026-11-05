import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/agent_protocol.dart';
import 'package:phone_agent/features/conversation/domain/history/conversation_history.dart';
import 'package:phone_agent/features/conversation/domain/history/ledger_event.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_controller.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_state.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/conversation_option_values.dart';

void main() {
  test(
    'live no-phone selection and restore keep facts without reviving an old pending',
    () async {
      final gateway = _Gateway();
      final history = _History();
      final controller = ConversationController(
        entry: const ConversationEntry(
          sessionId: 's',
          skillId: 'restaurant_booking',
        ),
        accountId: 'synthetic',
        gateway: gateway,
        history: history,
      );
      addTearDown(controller.dispose);
      const items = [
        {
          'id': 'opt_2',
          'label': '指定分店',
          'category': 'restaurant',
          'address': '合成路一号',
          'phoneAvailable': false,
        },
        {
          'id': 'opt_1',
          'label': '另一分店',
          'category': 'restaurant',
          'phoneAvailable': true,
        },
      ];
      controller.send('查指定品牌');
      gateway.stream.add(
        const AgentEvent(
          AgentEventKind.signal,
          sessionId: 's',
          text: '请选择',
          payload: {
            'type': 'SHOW_OPTIONS',
            'pendingToolCallId': 'choice',
            'options': {'title': '请选择', 'items': items},
          },
        ),
      );
      gateway.stream.add(const AgentEvent(AgentEventKind.done));
      await Future<void>.delayed(Duration.zero);
      final live = controller.state.messages.singleWhere(
        (m) => m.options.isNotEmpty,
      );
      expect(live.options.map((o) => o.label), ['指定分店', '另一分店']);
      expect(live.options.first.restaurant!.phoneAvailable, false);
      expect(live.options.first.restaurant!.phoneNotice, '暂无可拨打电话');
      expect(controller.choose(live.id, 0), true);
      expect(gateway.commands, hasLength(2));
      expect(gateway.commands.last.pendingToolCallId, 'choice');
      expect(gateway.commands.last.message, '第 1 个');
      gateway.stream.add(const AgentEvent(AgentEventKind.done));
      await Future<void>.delayed(Duration.zero);

      LedgerEvent event(
        int sequence,
        String type,
        String id, {
        bool options = false,
      }) => LedgerEvent(
        eventId: 'e$sequence',
        sessionId: 's',
        sequence: sequence,
        type: type,
        schemaVersion: 1,
        commandId: id == 'choice' ? 'search-command' : 'next-command',
        payload: {
          'toolName': options || id == 'choice' ? 'showOptions' : 'askUser',
          'toolCallId': id,
          'modelTurnId': id == 'choice' ? 'search-turn' : 'next-turn',
          'displayPayloadVersion': 1,
          'arguments': options
              ? {'title': '请选择', 'optionsJson': items}
              : {'question': '还需要帮助吗？'},
        },
      );
      final facts = [
        event(1, 'TOOL_REQUESTED', 'choice', options: true),
        event(2, 'TOOL_RESULT_RECORDED', 'choice'),
        event(3, 'TOOL_REQUESTED', 'next'),
      ];
      history.value = RestoredConversation(
        const ConversationDetail(
          sessionId: 's',
          title: '原任务',
          status: 'RUNNING',
        ),
        ledger: LedgerSnapshot(
          's',
          3,
          const LedgerProjection(
            status: 'RUNNING',
            continuable: true,
            pendingRestorable: true,
            migrationStatus: 'CURRENT',
            projectedThrough: 3,
          ),
          facts,
        ),
      );
      await controller.restore();
      await controller.restore();
      final restored = controller.state.messages.singleWhere(
        (m) => m.options.isNotEmpty,
      );
      expect(
        conversationOptionValues(restored),
        conversationOptionValues(live),
      );
      expect(controller.state.pendingToolCallId, 'next');
      expect(controller.choose(restored.id, 0), false);
      expect(
        controller.state.messages.where((m) => m.confirmation != null),
        isEmpty,
      );
      expect(gateway.commands, hasLength(2), reason: '恢复不生成拨号、保存或新搜索命令');
    },
  );
}

class _Gateway implements AgentGateway {
  final commands = <AgentCommand>[];
  var stream = StreamController<AgentEvent>();
  @override
  AgentRun start(AgentCommand command) {
    commands.add(command);
    stream = StreamController<AgentEvent>();
    return AgentRun(stream.stream, () {});
  }
}

class _History implements ConversationHistoryRepository {
  RestoredConversation value = const RestoredConversation(
    ConversationDetail(sessionId: 's', title: '任务', status: 'RUNNING'),
  );
  @override
  Future<RestoredConversation> restore(String sessionId) async => value;
}
