import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/agent_protocol.dart';
import 'package:phone_agent/features/conversation/domain/history/conversation_history.dart';
import 'package:phone_agent/features/conversation/domain/tools/conversation_permission.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_controller.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_state.dart';
import 'package:phone_agent/features/conversation/presentation/pages/conversation_page.dart';
import 'conversation_permission_test.dart' show PermissionFake, signal;

const _denied = '未获得定位权限，可告诉我城市或区域。';
const _blocked = '定位权限未开启，可在系统设置中授权或告诉我具体区域。';

void main() {
  for (final phase in [ConversationPhase.closed, ConversationPhase.restoring]) {
    testWidgets('$phase does not present a late permission toast', (
      tester,
    ) async {
      final notices = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConversationPage(
              state: ConversationState(
                entry: const ConversationEntry(sessionId: 's'),
                phase: phase,
                notice: _blocked,
              ),
              modelName: '模型',
              onClose: () {},
              onToggle: () {},
              onSend: (_) => true,
              onChoose: (_, __) => true,
              onRetry: () {},
              onModels: () {},
              onNotice: notices.add,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(notices, isEmpty);
    });
  }
  for (final blocked in [false, true]) {
    test(
      'location denial blocked=$blocked keeps exact permission action',
      () async {
        final gateway = _Gateway();
        final controller = ConversationController(
          entry: const ConversationEntry(sessionId: 's'),
          accountId: 'synthetic',
          gateway: gateway,
          history: _History(),
          permissions: PermissionFake(
            check: blocked ? PermissionGrant.blocked : PermissionGrant.denied,
            request: PermissionGrant.denied,
          ),
        );
        addTearDown(() async {
          controller.dispose();
          for (final stream in gateway.streams) {
            await stream.close();
          }
        });
        controller.send('附近餐厅');
        gateway.streams.first.add(signal(key: 'location', android: null));
        await Future<void>.delayed(Duration.zero);
        expect(gateway.commands.last.actionId, 'permission_result');
        expect(
          gateway.commands.last.actionPayload?['status'],
          blocked ? 'SETTINGS_REQUIRED' : 'DENIED',
        );
        expect(controller.state.notice, blocked ? _blocked : _denied);
      },
    );
    testWidgets(
      'location denial blocked=$blocked is transient and not repeated',
      (tester) async {
        final notices = <String>[];
        Future<void> show(String notice) async {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: ConversationPage(
                  state: ConversationState(
                    entry: const ConversationEntry(sessionId: 's'),
                    notice: notice,
                  ),
                  modelName: '模型',
                  onClose: () {},
                  onToggle: () {},
                  onSend: (_) => true,
                  onChoose: (_, __) => true,
                  onRetry: () {},
                  onModels: () {},
                  onNotice: notices.add,
                  onPermissionSettings: () {},
                ),
              ),
            ),
          );
          await tester.pump();
        }

        final text = blocked ? _blocked : _denied;
        await show('');
        await show(text);
        expect(notices, [text]);
        expect(find.text('去设置'), findsNothing);
        expect(find.text(text), findsNothing);
        await show(text);
        expect(notices, [text]);
        await show('');
        await show(text);
        expect(notices, [text, text]);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

class _Gateway implements AgentGateway {
  final commands = <AgentCommand>[];
  final streams = <StreamController<AgentEvent>>[];
  @override
  AgentRun start(AgentCommand command) {
    commands.add(command);
    final stream = StreamController<AgentEvent>();
    streams.add(stream);
    return AgentRun(stream.stream, () {});
  }
}

class _History implements ConversationHistoryRepository {
  @override
  Future<RestoredConversation> restore(String sessionId) async =>
      const RestoredConversation(
        ConversationDetail(sessionId: 's', title: '', status: 'CLOSED'),
      );
}
