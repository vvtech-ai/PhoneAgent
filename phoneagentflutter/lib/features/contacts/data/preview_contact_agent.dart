import '../../conversation/domain/agent_protocol.dart';
import '../../conversation/domain/history/conversation_history.dart';
import '../../conversation/domain/tools/phone_contact_lookup.dart';
import '../../conversation/domain/tools/name_contact_lookup.dart';

/// No network/account dependencies. A deterministic interaction fixture only.
class PreviewContactAgent
    implements
        AgentGateway,
        ConversationHistoryRepository,
        ContactLookupContinuation,
        NameContactLookupContinuation {
  PreviewContactAgent({this.lookup = false});
  final bool lookup;
  @override
  AgentRun start(AgentCommand command) {
    var cancelled = false;
    Stream<AgentEvent> events() async* {
      if (cancelled) return;
      if (lookup && command.pendingToolCallId != null) {
        yield AgentEvent(
          AgentEventKind.finalResponse,
          sessionId: command.sessionId,
          text: 'MOCK：候选选择已回传“${command.message}”。未拨打电话或写入真实任务。',
        );
      } else if (lookup) {
        yield AgentEvent(
          AgentEventKind.signal,
          sessionId: command.sessionId,
          payload: {
            'type': 'LOOKUP_CONTACT_REQUEST',
            'phone': '2025550101',
            'pendingToolCallId': 'mock-lookup-${command.commandId}',
          },
        );
      } else {
        yield AgentEvent(
          AgentEventKind.finalResponse,
          sessionId: command.sessionId,
          text:
              'MOCK：已收到您的文字。本演练仅验证联系人任务的输入与返回，'
              '没有创建真实任务或拨打电话。',
        );
      }
      if (!cancelled) yield const AgentEvent(AgentEventKind.done);
    }

    return AgentRun(events(), () => cancelled = true);
  }

  @override
  Future<AgentEvent> submit({
    required String sessionId,
    required String toolCallId,
    required Map<String, Object?> result,
  }) async => AgentEvent(
    AgentEventKind.signal,
    sessionId: sessionId,
    payload: {
      'type': 'LOOKUP_DEVICE_CONTACTS_BY_NAMES_REQUEST',
      'names': ['演示联系人'],
      'pendingToolCallId': '$toolCallId-names',
    },
  );

  @override
  Future<AgentEvent> submitNames({
    required String sessionId,
    required String toolCallId,
    required List<Map<String, Object?>> results,
  }) async => AgentEvent(
    AgentEventKind.signal,
    sessionId: sessionId,
    text: 'MOCK：已收到您的文字。共享查询找到演示联系人，请确认同名候选。',
    payload: {
      'type': 'SHOW_OPTIONS',
      'pendingToolCallId': '$toolCallId-select',
      'options': {
        'items': [
          for (final result in results)
            for (final candidate in result['candidates'] as List? ?? [])
              {
                'label': candidate['displayName'],
                'phone': candidate['phoneNumber'],
              },
        ],
      },
    },
  );

  @override
  Future<RestoredConversation> restore(String sessionId) =>
      Future.error(UnsupportedError('Preview has no persisted conversation'));
}
