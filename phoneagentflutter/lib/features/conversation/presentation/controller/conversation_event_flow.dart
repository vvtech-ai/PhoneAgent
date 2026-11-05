import '../../domain/agent_protocol.dart';
import '../../domain/conversation_event_contract.dart';
import '../../domain/agent_failure.dart';
import '../../domain/receipts/batch_progress_tracker.dart';
import '../../domain/receipts/batch_receipt_projector.dart';
import '../../domain/history/ledger_event.dart';
import '../../domain/conversation_live_messages.dart';
import '../../domain/memory_notice.dart';
import 'conversation_message_store.dart';
import 'conversation_state.dart';

/// Serial event dispatch over the existing ledger, tools and call owners.
class ConversationEventFlow {
  ConversationEventFlow({
    required this.read,
    required this.write,
    required this.current,
    required this.messages,
    required this.batch,
    required this.observed,
    required this.commit,
    required this.signal,
    required this.status,
    required this.done,
    required this.failed,
    required this.batchFinished,
    required this.publish,
    required this.assistant,
    this.suppressInteractions,
    this.onFinalResponse,
  });
  final ConversationState Function() read;
  final void Function(ConversationState) write;
  final bool Function(int) current;
  final ConversationMessageStore messages;
  final BatchProgressTracker batch;
  final void Function(AgentEvent, String command) observed;
  final Future<bool> Function(LedgerEvent, int) commit;
  final Future<void> Function(AgentEvent, String, int) signal;
  final void Function(AgentEvent, String, int) status;
  final Future<void> Function(String, int) done;
  final void Function(int, Object?) failed;
  final void Function() batchFinished, publish;
  final void Function(String, String) assistant;
  final bool Function()? suppressInteractions;
  final void Function(AgentEvent, String, int)? onFinalResponse;
  final _interactions = <(String, String, String)>{};
  String _delta = '';
  void reset() {
    _delta = '';
    _interactions.clear();
  }

  Future<void> accept(AgentEvent event, String command, int generation) async {
    if (!current(generation)) return;
    if (event.sessionId.isNotEmpty &&
        event.sessionId != read().entry.sessionId) {
      return;
    }
    final wireCommand = event.payload['commandId'];
    if (event.kind != AgentEventKind.committed &&
        wireCommand is String &&
        wireCommand.isNotEmpty &&
        wireCommand != command) {
      return;
    }
    final type = ConversationEventContract.businessType(event);
    final interactive =
        (event.kind == AgentEventKind.signal ||
            event.kind == AgentEventKind.finalResponse) &&
        ConversationEventContract.isInteractive(event);
    if ((event.kind == AgentEventKind.signal || interactive) &&
        suppressInteractions?.call() == true &&
        !BatchProgressTracker.isFinal(event) &&
        !const {'CALL_RESULT', 'TEXT_REPLY'}.contains(event.payload['type'])) {
      return;
    }
    final tool = event.payload['pendingToolCallId'];
    if (interactive &&
        tool is String &&
        tool.isNotEmpty &&
        !_interactions.add((command, type ?? '', tool))) {
      return;
    }
    final finalBatch = BatchProgressTracker.isFinal(event);
    final batchId =
        BatchReceiptProjector.payload(
          event.payload,
        )['batchId']?.toString().trim() ??
        '';
    if (finalBatch &&
        batchId.isNotEmpty &&
        (batch.completed(batchId) ||
            batch.active &&
                batch.batchId.isNotEmpty &&
                batch.batchId != batchId)) {
      return;
    }
    observed(event, command);
    if (event.kind == AgentEventKind.signal || interactive) {
      final notice = MemoryNotice.prefix(event.text);
      if (notice.isNotEmpty) {
        messages.upsert(ConversationLiveMessages.memoryNotice(command, notice));
        publish();
      }
    }
    if (event.payload['type'] == 'MEMORY_NOTICE') {
      if (event.text.trim().isNotEmpty) {
        messages.upsert(
          ConversationLiveMessages.memoryNotice(command, event.text),
        );
        publish();
      }
      return;
    }
    if (event.kind == AgentEventKind.toolComplete) {
      messages.artifacts(event.payload, command);
      publish();
    }
    if (batch.accept(event, command)) {
      messages.batch(command, batch.snapshot());
      publish();
      write(
        read().copy(
          phase: batch.uncertain
              ? ConversationPhase.ready
              : ConversationPhase.sending,
          activity: batch.uncertain
              ? '外呼请求失败，正在核对拨号状态，请稍后刷新'
              : event.text.trim().isNotEmpty
              ? event.text
              : '正在执行多路外呼，完成后会汇总结果',
        ),
      );
    }
    if (BatchProgressTracker.isFinal(event)) {
      final hadPending = read().messages.any(
        (message) =>
            message.transient &&
            message.id.endsWith(':batch-progress') &&
            message.commandId == command &&
            message.batchReceipt != null &&
            (batchId.isEmpty || message.batchReceipt!.explicitId == batchId),
      );
      messages.finishThinking(command);
      batch.finish(command, batchId: batchId);
      messages.finish(event.payload, command, publicText: event.text);
      publish();
      final projected = read();
      if (hadPending &&
          projected.notice == batchUnconfirmedNotice &&
          projected.messages.any(
            (message) =>
                message.commandId == command &&
                !message.id.endsWith(':batch-progress') &&
                message.batchReceipt?.isRunning == false &&
                (batchId.isEmpty ||
                    message.batchReceipt?.explicitId == batchId),
          )) {
        write(projected.copy(notice: ''));
      }
      batchFinished();
      if (event.kind == AgentEventKind.signal) {
        if (event.text.isNotEmpty) assistant(command, event.text);
        return;
      }
    }
    switch (event.kind) {
      case AgentEventKind.text:
        _delta += event.text;
        assistant(command, _delta);
      case AgentEventKind.thinking:
        messages.think(command, event);
        publish();
        write(read().copy(activity: '正在思考…'));
      case AgentEventKind.thinkingDone:
        messages.think(command, event);
        publish();
        write(read().copy(activity: ''));
      case AgentEventKind.committed:
        if (!await commit(event.ledger!, generation) && current(generation)) {
          failed(generation, null);
        }
      case AgentEventKind.signal:
        await signal(event, command, generation);
      case AgentEventKind.finalResponse:
        if (interactive) {
          await signal(event, command, generation);
          return;
        }
        onFinalResponse?.call(event, command, generation);
        messages.finishThinking(command);
        messages.finish(event.payload, command, publicText: event.text);
        publish();
        if (event.text.isNotEmpty) assistant(command, event.text);
        write(read().copy(activity: ''));
      case AgentEventKind.error:
        messages.finishThinking(command);
        publish();
        failed(generation, AgentFailure.fromEvent(event));
      case AgentEventKind.done:
        messages.finishThinking(command);
        publish();
        await done(command, generation);
      case AgentEventKind.toolCard:
        final message = ConversationLiveMessages.toolCard(
          command,
          event.payload,
        );
        if (read().phase != ConversationPhase.sending &&
            !message.toolCard!.remainsAfterTurn) {
          return;
        }
        messages.upsert(message);
        publish();
      case AgentEventKind.status:
      case AgentEventKind.toolStart:
      case AgentEventKind.toolComplete:
        status(event, command, generation);
      case AgentEventKind.heartbeat:
      case AgentEventKind.unknown:
        break;
    }
  }
}
