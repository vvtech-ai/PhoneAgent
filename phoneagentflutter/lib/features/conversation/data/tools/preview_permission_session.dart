import '../../domain/agent_protocol.dart';
import '../../domain/history/conversation_history.dart';
import '../../domain/tools/conversation_permission.dart';

enum PermissionPreviewScenario { allow, deny, settings, alreadyGranted }

/// Synthetic ports for the real conversation controller; no account or device.
class PreviewPermissionSession
    implements
        AgentGateway,
        ConversationHistoryRepository,
        ConversationPermissionSource {
  PermissionPreviewScenario scenario = PermissionPreviewScenario.allow;
  final commands = <AgentCommand>[];
  final requests = <bool>[];

  @override
  Future<PermissionGrant> resolve(
    ConversationPermission permission, {
    required bool request,
  }) async {
    requests.add(request);
    final selected = scenario;
    await Future<void>.delayed(const Duration(milliseconds: 150));
    return switch (selected) {
      PermissionPreviewScenario.alreadyGranted => PermissionGrant.granted,
      PermissionPreviewScenario.settings => PermissionGrant.unavailable,
      PermissionPreviewScenario.allow when request => PermissionGrant.granted,
      _ => PermissionGrant.denied,
    };
  }

  @override
  AgentRun start(AgentCommand command) {
    commands.add(command);
    var cancelled = false;
    Stream<AgentEvent> run() async* {
      if (cancelled) return;
      if (command.actionId == 'permission_result') {
        yield AgentEvent(
          AgentEventKind.finalResponse,
          sessionId: command.sessionId,
          text:
              'MOCK：已收到权限结果 ${command.actionPayload?['status']}，对话已继续。未申请真实权限或调用真实 Agent。',
          payload: const {'type': 'TEXT_REPLY'},
        );
      } else {
        yield AgentEvent(
          AgentEventKind.signal,
          sessionId: command.sessionId,
          payload: {
            'type': 'REQUEST_PERMISSION',
            'pendingToolCallId': 'mock-permission-${command.commandId}',
            'permissionRequest': {
              'permissionKey': 'contacts',
              'androidPermission': 'android.permission.READ_CONTACTS',
              'reason': '合成权限交互，不读取联系人',
            },
          },
        );
      }
      if (!cancelled) yield const AgentEvent(AgentEventKind.done);
    }

    return AgentRun(run(), () => cancelled = true);
  }

  @override
  Future<RestoredConversation> restore(String sessionId) async =>
      RestoredConversation(
        ConversationDetail(
          sessionId: sessionId,
          title: 'MOCK',
          status: 'CLOSED',
        ),
      );
}
