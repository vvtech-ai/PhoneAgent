import '../../domain/agent_protocol.dart';
import '../../domain/conversation_messages.dart';
import '../../domain/conversation_permission_presentation.dart';
import '../../domain/tools/conversation_permission.dart';
import '../../domain/tools/conversation_action_coordinator.dart';
import 'conversation_message_store.dart';
import 'conversation_state.dart';
import '../../domain/context/conversation_permission_resume.dart';

class ConversationActionFlow {
  const ConversationActionFlow({
    required this.coordinator,
    required this.read,
    required this.write,
    required this.messages,
    required this.nextId,
    required this.accountId,
    required this.userContext,
    required this.start,
    this.permissionResume,
    this.beginSpeech,
  });
  final ConversationActionCoordinator coordinator;
  final ConversationState Function() read;
  final void Function(ConversationState) write;
  final ConversationMessageStore messages;
  final String Function() nextId;
  final String accountId;
  final Map<String, Object?>? Function() userContext;
  final void Function(AgentCommand) start;
  final ConversationPermissionResume? permissionResume;
  final void Function()? beginSpeech;

  Future<void> run(
    AgentEvent event,
    String command,
    bool Function() current,
  ) async {
    final document = event.payload['type'] == 'IMPORT_DOCUMENT_REQUEST';
    if (document && event.text.isNotEmpty) {
      messages.assistant(command, event.text, const [], null);
      write(messages.project(read()));
    }
    write(
      read().copy(
        activity: document ? '等待选择文档…' : '正在检查系统权限…',
        clearOptions: true,
      ),
    );
    final result = !document && permissionResume != null
        ? await permissionResume!.run(
            (valid) => coordinator.resolve(event, isCurrent: valid),
            current,
          )
        : await coordinator.resolve(event, isCurrent: current);
    if (!current() || result == null) return;
    final permission = result.action == 'permission_result';
    if (permission) {
      final message = ConversationPermissionPresentation.result(
        read().messages,
        command,
        event.payload['pendingToolCallId']?.toString() ?? '',
        result.payload,
      );
      if (message != null) messages.upsert(message);
    }
    final next = result.command(
      read().entry.sessionId,
      accountId,
      nextId(),
      nextId(),
      userContext(),
    );
    if (result.echo.isNotEmpty) {
      messages.upsert(
        ConversationMessage(
          id: 'local-user:${next.commandId}',
          commandId: next.commandId,
          role: MessageRole.user,
          text: result.echo,
          transient: true,
        ),
      );
    }
    write(
      messages
          .project(read())
          .copy(
            phase: ConversationPhase.sending,
            activity: '继续处理…',
            notice: permission && result.payload['permissionKey'] == 'location'
                ? switch (result.payload['status']) {
                    'DENIED' => locationPermissionDeniedToast,
                    'SETTINGS_REQUIRED' => locationPermissionBlockedToast,
                    _ => '',
                  }
                : '',
          ),
    );
    if (permission) beginSpeech?.call();
    start(next);
  }
}
