import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/agent_protocol.dart';
import 'package:phone_agent/features/conversation/domain/conversation_messages.dart';
import 'package:phone_agent/features/conversation/domain/history/conversation_history.dart';
import 'package:phone_agent/features/conversation/domain/tools/conversation_permission.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_controller.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_state.dart';
import 'conversation_permission_test.dart' show PermissionFake, signal;

void main() {
  for (final grant in [PermissionGrant.granted, PermissionGrant.denied]) {
    test(
      'real $grant result replaces waiting card and survives continuation',
      () async {
        final gateway = _Gateway();
        final permissions = PermissionFake();
        final pending = Completer<PermissionGrant>();
        permissions.pendingRequest = pending.future;
        var id = 0;
        final controller = ConversationController(
          entry: const ConversationEntry(sessionId: 's'),
          accountId: 'synthetic',
          gateway: gateway,
          history: _History(),
          permissions: permissions,
          nextId: () => 'c${++id}',
        );
        addTearDown(() async {
          controller.dispose();
          for (final stream in gateway.streams) {
            await stream.close();
          }
        });
        controller.send('附近餐厅');
        final first = gateway.streams.single;
        first.add(
          const AgentEvent(
            AgentEventKind.toolCard,
            payload: {
              'toolCallId': 'tool',
              'toolName': 'requestPermission',
              'body': 'reason: "附近餐厅"',
              'result': '等待用户授权',
              'status': 'waiting',
            },
          ),
        );
        first.add(signal());
        await Future<void>.delayed(Duration.zero);
        pending.complete(grant);
        await Future<void>.delayed(Duration.zero);
        final cards = controller.state.messages.where(
          (m) => m.toolCard != null,
        );
        expect(cards, hasLength(1));
        expect(
          cards.single.toolCard!.result,
          grant == PermissionGrant.granted ? '授权成功' : '用户未授权',
        );
        expect(
          cards.single.toolCard!.status,
          grant == PermissionGrant.granted ? 'OK' : 'DENIED',
        );
        expect(cards.single.toolCard!.body, 'reason: "附近餐厅"');
        gateway.streams.last.add(
          const AgentEvent(AgentEventKind.text, text: '继续处理'),
        );
        gateway.streams.last.add(const AgentEvent(AgentEventKind.done));
        await Future<void>.delayed(Duration.zero);
        expect(
          controller.state.messages.where((m) => m.toolCard != null),
          hasLength(1),
        );
        expect(
          controller.state.messages.where((m) => m.role == MessageRole.user),
          hasLength(1),
        );
        expect(controller.state.messages.last.text, '继续处理');
      },
    );
  }
}

class _Gateway implements AgentGateway {
  final streams = <StreamController<AgentEvent>>[];
  @override
  AgentRun start(AgentCommand command) {
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
