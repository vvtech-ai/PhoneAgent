import 'dart:developer' as developer;

import '../../../../core/diagnostics/diagnostic_journal.dart';
import '../../domain/conversation_messages.dart';
import '../../domain/conversation_questions.dart';
import '../../domain/conversation_thinking.dart';
import '../../domain/confirmation/call_confirmation_prompt.dart';
import '../../domain/agent_protocol.dart';
import '../../domain/artifacts/task_artifact_projection.dart';
import '../../domain/conversation_live_messages.dart';
import '../../domain/receipts/batch_receipt.dart';
import '../../domain/receipts/batch_receipt_projector.dart';
import '../../domain/receipts/receipt_message_mapper.dart';
import '../../domain/history/ledger_event.dart';
import '../../domain/history/conversation_history.dart';
import '../../../calls/domain/call_launch_coordinator.dart';
import 'conversation_call_notice.dart';
import 'conversation_fact_sync.dart';
import 'conversation_presentation_projection.dart';
import 'conversation_state.dart';
import '../../domain/voice/conversation_turn_recovery.dart';

/// Owns the local fact view and transient overlays, never changes server facts.
class ConversationMessageStore {
  final Map<String, LedgerEvent> facts = {};
  final acceptedInputs = <String>{};
  final List<ConversationMessage> messages = [];
  final _revisedUsers = <String>{};
  void clear() {
    acceptedInputs.clear();
    _revisedUsers.clear();
    facts.clear();
    messages.clear();
  }

  /// Drops the live projection while preserving the authoritative fact cache.
  /// Restore uses this boundary so local opening/choice/progress overlays cannot
  /// leak into a rebuilt history timeline.
  void resetProjection() => messages.clear();

  void replaceFacts(LedgerSnapshot? ledger) {
    _revisedUsers.clear();
    facts.clear();
    for (final fact in ledger?.events ?? <LedgerEvent>[]) {
      facts[fact.eventId] = fact;
    }
  }

  Future<bool> sync(
    ConversationHistoryRepository history,
    String sessionId,
    bool Function() current, {
    required void Function() onApplied,
    void Function(LedgerSnapshot)? onLedgerApplied,
  }) async {
    final restored = await history.restore(sessionId);
    if (!current()) return false;
    final ledger = restored.ledger;
    final applied =
        ledger != null &&
        ledger.sessionId == sessionId &&
        ConversationFactSync.merge(facts, ledger);
    if (applied) {
      onApplied();
      onLedgerApplied?.call(ledger);
    }
    return applied;
  }

  ConversationState project(ConversationState state) {
    final rejected = ConversationMessages.rejectedCallIds(
      facts.values.where((e) => e.sessionId == state.entry.sessionId),
    );
    messages.removeWhere(
      (m) =>
          (m.confirmation != null || m.batchConfirmation != null) &&
          rejected.contains(m.toolCallId),
    );
    final projected = ConversationPresentationProjection.live(
      state,
      facts.values,
      messages,
    );
    return projected.copy(
      messages: projected.messages
          .where(
            (m) =>
                m.role != MessageRole.user ||
                !_revisedUsers.contains(m.commandId),
          )
          .toList(),
    );
  }

  bool applyRecovery(RecoveredTurnPlan plan) {
    if (!ConversationFactSync.merge(facts, plan.ledger)) return false;
    if (plan.originalCommitted) {
      messages.removeWhere((m) => m.commandId == plan.originalCommand);
    }
    return true;
  }

  void reviseUser(String command) {
    _revisedUsers.add(command);
    messages.removeWhere(
      (m) => m.commandId == command && m.role == MessageRole.user,
    );
  }

  void discardPartialReply(String command) => messages.removeWhere(
    (m) =>
        m.commandId == command &&
        !ConversationLiveMessages.isMemoryNotice(m) &&
        !ConversationLiveMessages.isConfirmationPrompt(m) &&
        m.role == MessageRole.assistant &&
        m.thinking == null &&
        m.receipt == null &&
        m.batchReceipt == null &&
        m.confirmation == null,
  );

  ConversationState blocked(ConversationState state, CallLaunchState launch) {
    final message = ConversationCallNotice.message(launch);
    if (message != null && !messages.any((m) => m.id == message.id)) {
      messages.add(message);
    }
    return state.copy(
      phase: ConversationPhase.ready,
      activity: '',
      notice: ConversationCallNotice.warning(launch),
    );
  }

  void upsert(ConversationMessage message) {
    assert(() {
      if (configuredDiagnosticLogLevel != DiagnosticLogLevel.debug) return true;
      developer.log(
        '[conversation-msg] op=upsert id=${message.id} '
        'command=${message.commandId ?? ''} role=${message.role.name} '
        'tool=${message.toolCard?.toolName ?? ''} '
        'toolCall=${message.toolCallId ?? ''} options=${message.options.length} '
        'thinkingLen=${message.thinking?.toString().length ?? 0} textLen=${message.text.length}',
        name: 'phone_agent',
      );
      return true;
    }());
    final index = messages.indexWhere((m) => m.id == message.id);
    if (index < 0) {
      messages.add(message);
    } else {
      messages[index] = message;
    }
  }

  void assistant(
    String command,
    String text,
    List<ConversationOption> options,
    String? tool,
  ) => upsert(ConversationLiveMessages.assistant(command, text, options, tool));

  ConversationState interactive(
    ConversationState state,
    String command,
    AgentEvent event,
    String tool,
  ) {
    if (event.payload['type'] == 'ASK_USER') {
      final ask = ConversationMessages.questionPayload(event.payload);
      final fallback = event.text.trim().isNotEmpty
          ? event.text
          : ConversationMessages.text(event.payload, 'text');
      final content = ConversationMessages.questions(ask, fallback: fallback);
      if (content.isEmpty) return project(state);
      upsert(
        ConversationMessage(
          id: tool.isNotEmpty
              ? 'local:$command:question:$tool'
              : 'local:$command:assistant',
          role: MessageRole.assistant,
          text: content,
          commandId: command,
          transient: true,
          toolCallId: tool,
          questions: ConversationQuestions.parse(ask),
          questionSourceText: fallback,
        ),
      );
      return project(state).copy(pendingToolCallId: tool);
    }
    return _options(state, command, event.text, event.payload, tool);
  }

  ConversationState _options(
    ConversationState state,
    String command,
    String text,
    Map<String, Object?> payload,
    String tool,
  ) {
    assistant(
      command,
      text.isEmpty ? '请选择' : text,
      ConversationMessages.options(
        ConversationMessages.object(payload['options']),
      ),
      tool,
    );
    final projected = project(state);
    final durable = projected.messages
        .where((m) => m.toolCallId == tool && m.options.isNotEmpty)
        .lastOrNull;
    return projected.copy(
      activeOptionsId: durable?.id ?? 'local:$command:assistant',
      pendingToolCallId: tool,
    );
  }

  void batch(String command, BatchReceipt? receipt) {
    if (receipt == null) return;
    upsert(
      ConversationMessage(
        id: 'local:$command:batch-progress',
        role: MessageRole.assistant,
        text: '',
        commandId: command,
        batchReceipt: receipt,
        transient: true,
      ),
    );
  }

  void finish(
    Map<String, Object?> payload,
    String command, {
    String publicText = '',
  }) {
    artifacts(payload, command);
    final batchData = BatchReceiptProjector.payload(payload);
    final batchResult = batchData.isEmpty
        ? null
        : BatchReceipt.fromJson(batchData, fallbackId: '');
    final progressId = 'local:$command:batch-progress';
    final progress = messages.where((m) => m.id == progressId).firstOrNull;
    final progressBatchId = progress?.batchReceipt?.explicitId ?? '';
    final usableBatch =
        batchResult != null &&
        (batchResult.explicitId.isNotEmpty
            ? (batchResult.items.isNotEmpty ||
                      batchResult.totalCount > 0 ||
                      batchResult.isExecutionError) &&
                  (progressBatchId.isEmpty ||
                      progressBatchId == batchResult.explicitId)
            : batchResult.isExecutionError && batchResult.items.isEmpty);
    var position = -1;
    if (usableBatch) {
      position = messages.indexWhere((m) => m.id == progressId);
      messages.removeWhere((m) => m.id == 'local:$command:batch-progress');
    }
    for (final message in ReceiptMessageMapper.fromFinal({
      ...payload,
      if (publicText.isNotEmpty) 'text': publicText,
    }, command)) {
      if (message.batchReceipt != null && !usableBatch) continue;
      if (position >= 0 &&
          message.batchReceipt != null &&
          !messages.any((m) => m.id == message.id)) {
        messages.insert(position, message);
      } else {
        upsert(message);
      }
    }
  }

  void artifacts(Map<String, Object?> payload, String command) {
    for (final message in TaskArtifactProjection.messages(payload, command)) {
      upsert(message);
    }
  }

  void think(String command, AgentEvent event) {
    final prior = messages
        .where((m) => m.commandId == command && m.thinking != null)
        .lastOrNull;
    final thinking = (prior?.thinking ?? const ConversationThinking()).accept(
      event,
    );
    if (thinking.text.trim().isEmpty) return;
    upsert(
      ConversationMessage(
        id: 'local:$command:thinking',
        role: MessageRole.assistant,
        text: '',
        commandId: command,
        transient: true,
        thinking: thinking,
      ),
    );
  }

  /// A contact callback may be committed by the backend under a new
  /// continuation command. Keep the already visible thinking segment attached
  /// to that command so projection can place it before the callback reply.
  void rebindThinking(String fromCommand, String toCommand) {
    if (fromCommand == toCommand ||
        fromCommand.trim().isEmpty ||
        toCommand.trim().isEmpty) {
      return;
    }
    final source = messages
        .where((m) => m.commandId == fromCommand && m.thinking != null)
        .lastOrNull;
    if (source == null) return;
    messages.removeWhere(
      (m) => m.commandId == fromCommand && m.thinking != null,
    );
    messages.removeWhere((m) => m.commandId == toCommand && m.thinking != null);
    messages.add(
      ConversationMessage(
        id: 'local:$toCommand:thinking',
        role: source.role,
        text: source.text,
        commandId: toCommand,
        transient: source.transient,
        thinking: source.thinking,
      ),
    );
  }

  void finishThinking(String command) =>
      think(command, const AgentEvent(AgentEventKind.thinkingDone));

  void confirmation(String command, String tool, Map<String, Object?> spec) {
    final message = ConversationLiveMessages.confirmation(command, tool, spec);
    if (message == null) return;
    upsert(message);
    upsert(
      ConversationMessage(
        id: 'local:$command:confirmation-prompt:$tool',
        role: MessageRole.assistant,
        text: CallConfirmationPrompt.text,
        commandId: command,
        toolCallId: tool.isEmpty ? null : tool,
        transient: true,
      ),
    );
  }

  void finishTools({String? commandId}) => messages.removeWhere(
    (m) =>
        (commandId == null || m.commandId == commandId) &&
        m.toolCard != null &&
        !m.toolCard!.remainsAfterTurn,
  );
}
