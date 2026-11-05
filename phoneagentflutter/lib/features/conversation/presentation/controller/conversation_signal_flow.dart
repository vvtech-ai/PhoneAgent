import '../../domain/agent_protocol.dart';
import '../../domain/conversation_messages.dart';
import '../../domain/conversation_live_messages.dart';
import '../../domain/confirmation/batch_confirmation_prompt_presentation.dart';
import '../../domain/tools/conversation_tool_coordinator.dart';
import '../../../contacts/domain/contact_name_matcher.dart';
import 'conversation_action_flow.dart';
import 'conversation_message_store.dart';
import 'conversation_state.dart';
import '../../../calls/presentation/controller/conversation_call_controller.dart';

/// Live interactive routing. Historical hydration never calls this flow.
class ConversationSignalFlow {
  ConversationSignalFlow({
    required this.read,
    required this.write,
    required this.current,
    required this.messages,
    required this.tools,
    required this.actions,
    required this.handlesAction,
    required this.inputSource,
    required this.publish,
    required this.accept,
    required this.assistant,
    required this.notice,
    required this.calls,
  });
  final ConversationState Function() read;
  final void Function(ConversationState) write;
  final bool Function(int) current;
  final ConversationMessageStore messages;
  final ConversationToolCoordinator tools;
  final ConversationActionFlow Function() actions;
  final bool Function(String) handlesAction;
  final ContactInputSource Function() inputSource;
  final void Function() publish;
  final Future<void> Function(AgentEvent, String, int) accept;
  final void Function(String, String) assistant;
  final void Function(String) notice;
  final ConversationCallController? Function() calls;
  final Set<(String, String, String)> _handled = {};

  Future<void> run(AgentEvent event, String command, int generation) async {
    if (!current(generation)) return;
    final type = ConversationMessages.text(event.payload, 'type');
    final tool = ConversationMessages.text(event.payload, 'pendingToolCallId');
    final call = calls();
    final previousTool = call?.snapshot.launch.request?.toolId;
    if (previousTool != null &&
        (previousTool != tool || type != 'MAKE_CALL_REQUEST')) {
      call?.cancelPending();
    }
    if (tool.isNotEmpty && !_handled.add((command, type, tool))) return;
    if (handlesAction(type)) {
      await actions().run(event, command, () => current(generation));
      return;
    }
    if (tools.handles(type)) {
      if (tools.hasHandled(tool)) return;
      write(read().copy(activity: '正在查询本机联系人…', clearOptions: true));
      final result = await tools.run(
        event: event,
        sessionId: read().entry.sessionId,
        commandId: command,
        inputSource: inputSource(),
        onNotice: notice,
        hasLedger: messages.facts.isNotEmpty,
        isCurrent: () => current(generation),
      );
      if (!current(generation)) return;
      if (result == null) {
        write(read().copy(activity: ''));
        return;
      }
      if (result.commandId != command) {
        messages.rebindThinking(command, result.commandId);
      }
      final responseType = ConversationMessages.text(
        result.event.payload,
        'type',
      );
      final responseTool = ConversationMessages.text(
        result.event.payload,
        'pendingToolCallId',
      );
      if (responseType == 'SHOW_OPTIONS' && responseTool.isNotEmpty) {
        final options = ConversationMessages.object(
          result.event.payload['options'],
        );
        final items = ConversationMessages.array(
          options['items'] ?? options['optionsJson'],
        );
        messages.upsert(
          ConversationLiveMessages.toolCard(result.commandId, {
            'toolCallId': responseTool,
            'toolName': 'showOptions',
            'methodLabel': 'showOptions()',
            'status': 'completed',
            'result': result.event.text,
            'conditions': [
              if (ConversationMessages.text(options, 'title').isNotEmpty)
                {
                  'label': 'title',
                  'value': ConversationMessages.text(options, 'title'),
                },
              {'label': 'options', 'value': items.length},
            ],
          }),
        );
      }
      if (result.ledger != null) {
        messages.replaceFacts(result.ledger);
        publish();
      }
      await accept(result.event, result.commandId, generation);
      return;
    }
    if (type == 'SHOW_OPTIONS' || type == 'ASK_USER') {
      final questions = ConversationMessages.questionPayload(event.payload);
      final batchPrompt =
          type == 'ASK_USER' &&
          ConversationMessages.text(questions, 'title') ==
              BatchConfirmationPromptPresentation.prompt;
      if (batchPrompt) {
        if (!await _hydrateBatchConfirmation(tool, generation)) return;
        messages.upsert(
          ConversationMessage(
            id: 'local:$command:batch-question:$tool',
            role: MessageRole.assistant,
            text: ConversationMessages.text(questions, 'title'),
            commandId: command,
            toolCallId: tool,
            transient: true,
          ),
        );
        write(read().copy(pendingToolCallId: tool));
      } else {
        write(messages.interactive(read(), command, event, tool));
      }
      publish();
    } else if (type == 'MAKE_CALL_REQUEST') {
      final nested = ConversationMessages.object(event.payload['callSpec']);
      final spec = nested.isEmpty ? event.payload : nested;
      final blocked = call?.callRequestBlockReason;
      if (blocked != null) {
        notice(blocked);
      } else {
        messages.confirmation(command, tool, spec);
        publish();
        if (call == null) {
          notice('通话执行能力尚未接入，当前仅显示任务信息，未拨号。');
        } else {
          call.receive(
            sessionId: read().entry.sessionId,
            commandId: command,
            toolId: tool,
            spec: spec,
          );
        }
      }
    } else {
      if (event.text.isNotEmpty) assistant(command, event.text);
      notice('此交互能力尚未接入，未执行权限、附件或通话操作。');
    }
    if (current(generation)) write(read().copy(activity: ''));
  }

  Future<bool> _hydrateBatchConfirmation(String tool, int generation) async {
    bool hasCard() =>
        tool.isNotEmpty &&
        read().messages.any(
          (m) => m.toolCallId == tool && m.batchConfirmation != null,
        );
    if (hasCard()) return true;
    try {
      await messages.sync(
        tools.history,
        read().entry.sessionId,
        () => current(generation),
        onApplied: publish,
      );
      if (!current(generation)) return false;
      if (hasCard()) return true;
    } catch (_) {
      if (!current(generation)) return false;
    }
    write(
      read().copy(
        phase: ConversationPhase.recoveryRequired,
        activity: '',
        notice: '任务确认卡同步失败，请同步历史重试；未开始执行。',
      ),
    );
    return false;
  }
}
