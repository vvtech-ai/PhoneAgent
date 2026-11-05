import 'dart:async';
import '../../../contacts/domain/contact_name_matcher.dart';
import '../../../attachments/domain/document_import.dart';
import '../../../conversation/domain/agent_protocol.dart';
import '../../../conversation/domain/history/conversation_history.dart';
import '../../../conversation/domain/conversation_messages.dart';
import '../../../conversation/presentation/controller/conversation_message_store.dart';
import '../../../conversation/presentation/controller/conversation_state.dart';
import '../../domain/apology_voice.dart';
import 'apology_voice_controller.dart';

typedef ApologyTaskSubmission =
    bool Function(
      String text, {
      ContactInputSource source,
      DocumentTurn? document,
    });

ApologyConversationBinding? initialApologyBinding(
  ConversationEntry entry,
  ApologyConversationBinding Function(String?) create,
) => entry.skillId == ApologyVoicePolicy.skillId && !entry.restore
    ? create(null)
    : null;

ApologyConversationBinding? restoreApologyBinding(
  ApologyConversationBinding? existing,
  RestoredConversation restored,
  ApologyConversationBinding Function(String?) create,
) =>
    existing ??
    (restored.detail.pinnedSkillId == ApologyVoicePolicy.skillId
        ? create(restored.detail.taskCallModelId)
        : null);

class ApologyVoiceDependencies {
  const ApologyVoiceDependencies({
    required this.port,
    required this.model,
    required this.modelName,
    this.modelNameFor,
    this.waitForPrecheck = false,
  });
  final ApologyVoicePort port;
  final String Function() model, modelName;
  final String Function(String)? modelNameFor;
  final bool waitForPrecheck;
}

/// Adapts local consent cards to the existing conversation and cancellation wire.
class ApologyConversationBinding {
  ApologyConversationBinding({
    required ApologyVoiceDependencies? dependencies,
    required this.gateway,
    required this.messages,
    required this.read,
    required this.write,
    required this.publish,
    required this.current,
    required this.nextId,
    required this.interrupt,
    required this.cancelStream,
    required this.accountId,
    required this.send,
    String? restoredModel,
  }) {
    voice = ApologyVoiceController(
      port: dependencies?.port,
      currentModel: dependencies?.model ?? () => '',
      currentModelName: dependencies?.modelName ?? () => '当前模型',
      modelNameFor: dependencies?.modelNameFor,
      isCurrent: current,
      interrupt: interrupt,
      cancelTask: _cancel,
      present: _present,
      onChoice: _recordChoice,
      onQueryStart: _queryStarted,
      resume: (text) => send(text),
    );
    if (restoredModel == null) {
      if (dependencies?.waitForPrecheck != true) begin();
    } else {
      _openingPresented = true;
      _started = true;
      voice.restore(restoredModel);
    }
  }
  late final ApologyVoiceController voice;
  final AgentGateway gateway;
  final ConversationMessageStore messages;
  final ConversationState Function() read;
  final void Function(ConversationState) write;
  final void Function() publish, interrupt;
  final void Function() cancelStream;
  final bool Function() current;
  final String Function() nextId;
  final String accountId;
  final ApologyTaskSubmission send;
  bool _openingPresented = false;
  String? _modelPromptMessageId;
  String? _modelChoiceMessageId;
  void begin() {
    if (_openingPresented || !current()) return;
    _openingPresented = true;
    voice.begin();
  }

  bool input(String text, ContactInputSource source, DocumentTurn? document) =>
      current() &&
      text.isNotEmpty &&
      (!_openingPresented ||
          voice.input(
            text,
            afterConsent: () => send(text, source: source, document: document),
          ));
  bool _started = false;
  AgentCommand? _cancellation;
  AgentRun? _cancelling;
  ConversationState? _suspended;

  void _queryStarted() {
    if (!current()) return;
    if (read().pendingToolCallId != null) {
      _suspended ??= read();
    }
    // Checking has no prompt. Keep the selected model card and action in their
    // existing history while suspending the pending task's operation rights.
    final previousModelChoice = messages.messages
        .where(
          (message) =>
              message.options.isNotEmpty && message.id == _modelChoiceMessageId,
        )
        .lastOrNull;
    final selectedModel = voice.modelId;
    if (voice.stage == ApologyVoiceStage.checking &&
        previousModelChoice != null &&
        selectedModel != null) {
      messages.messages.remove(previousModelChoice);
      final interactionId = previousModelChoice.id;
      final promptId = 'local:apology:model-prompt-text:$interactionId';
      final cardId = 'local:apology:model-choice-card:$interactionId';
      final selectedOptionIndex = previousModelChoice.options.indexWhere(
        (option) =>
            option.label.trim() == voice.modelName(selectedModel).trim(),
      );
      messages.upsert(
        ConversationMessage(
          id: promptId,
          role: MessageRole.assistant,
          text: previousModelChoice.text,
          commandId: promptId,
          transient: false,
        ),
      );
      messages.upsert(
        previousModelChoice.copyWith(
          id: cardId,
          commandId: cardId,
          transient: false,
          optionsLocked: true,
          optionsTitleVisible: false,
          selectedOptionIndex: selectedOptionIndex < 0
              ? null
              : selectedOptionIndex,
        ),
      );
      _modelPromptMessageId = promptId;
      final choiceId = 'local:apology:model-choice:$interactionId';
      messages.upsert(
        ConversationMessage(
          id: choiceId,
          role: MessageRole.user,
          text: '已选择：${voice.modelName(selectedModel)}',
          commandId: choiceId,
          transient: false,
        ),
      );
      _modelChoiceMessageId = choiceId;
    }
    final pending = read().pendingToolCallId;
    write(read().copy(clearOptions: true).copy(pendingToolCallId: pending));
    publish();
  }

  void _present(ApologyPrompt prompt) {
    if (!current()) return;
    if (voice.stage == ApologyVoiceStage.ready) {
      messages.upsert(
        ConversationMessage(
          id: 'local:apology:voice-ready:${prompt.id}',
          role: MessageRole.assistant,
          text: prompt.text,
          commandId: prompt.id,
          transient: false,
        ),
      );
    }
    final id = 'local:${prompt.id}:assistant';
    if (voice.stage != ApologyVoiceStage.checking &&
        voice.stage != ApologyVoiceStage.ready) {
      messages.upsert(
        ConversationMessage(
          id: id,
          role: MessageRole.assistant,
          text: prompt.text,
          commandId: prompt.id,
          toolCallId: prompt.id,
          transient: true,
          options: prompt.choices
              .map((c) => ConversationOption(c.label, ''))
              .toList(),
        ),
      );
      if (prompt.modelChoice) _modelChoiceMessageId = id;
    }
    publish();
    final suspended = voice.stage == ApologyVoiceStage.ready
        ? _suspended
        : null;
    write(
      read().copy(
        activeOptionsId:
            suspended?.activeOptionsId ?? (prompt.choices.isEmpty ? null : id),
        pendingToolCallId: suspended?.pendingToolCallId,
        clearOptions: prompt.choices.isEmpty && suspended == null,
      ),
    );
    if (suspended != null || voice.stage == ApologyVoiceStage.stopped) {
      _suspended = null;
    }
  }

  void _recordChoice(ApologyPrompt prompt, int index) {
    if (!current() || index < 0 || index >= prompt.choices.length) return;
    final id = 'local:${prompt.id}:assistant';
    final old = messages.messages
        .where((message) => message.id == id)
        .firstOrNull;
    if (old == null || read().activeOptionsId != id) return;
    messages.upsert(
      old.copyWith(optionsLocked: true, selectedOptionIndex: index),
    );
    if (!prompt.modelChoice) {
      final actionId = 'apology:choice:${nextId()}';
      messages.upsert(
        ConversationMessage(
          id: 'local:$actionId:user',
          role: MessageRole.user,
          text: prompt.choices[index].label,
          commandId: actionId,
          transient: true,
        ),
      );
    }
    final pending = read().pendingToolCallId;
    write(read().copy(clearOptions: true).copy(pendingToolCallId: pending));
    publish();
  }

  bool? choose(String messageId, int index) {
    if (!messageId.startsWith('local:apology:')) return null;
    final prompt = voice.prompt;
    if (!current() ||
        prompt == null ||
        read().activeOptionsId != messageId ||
        messageId != 'local:${prompt.id}:assistant' ||
        index < 0 ||
        index >= prompt.choices.length) {
      return false;
    }
    voice.choose(prompt.choices[index].id);
    return true;
  }

  AgentCommand command(AgentCommand original) {
    if (voice.blocked) {
      throw StateError('Apology voice unconfirmed');
    }
    final firstCommand = !_started;
    _started = true;
    voice.submitted();
    final modelPrompt = messages.messages
        .where(
          (message) =>
              message.id == _modelPromptMessageId && !message.transient,
        )
        .lastOrNull;
    final modelChoice = messages.messages
        .where(
          (message) =>
              message.id.startsWith('local:apology:model-choice:') &&
              !message.transient,
        )
        .lastOrNull;
    if (firstCommand) {
      for (var index = 0; index < messages.messages.length; index++) {
        final record = messages.messages[index];
        if (record.id.startsWith('local:apology:')) {
          messages.messages[index] = record.copyWith(
            insertBeforeCommandId: original.commandId,
          );
        }
      }
    }
    publish();
    if (voice.selection == null) return original;
    return original.withCallVoiceSelection(
      voice.selection!.selection,
      opening: voice.selectionSummary ?? ApologyVoicePolicy.ready,
      assistantPrompt: modelPrompt?.text,
      userSelection: modelChoice?.text,
    );
  }

  Future<void> _cancel() async {
    if (!_started) return;
    cancelStream();
    write(read().copy(phase: ConversationPhase.ready, activity: ''));
    interrupt();
    _cancellation ??= AgentCommand(
      sessionId: read().entry.sessionId,
      userId: accountId,
      commandId: nextId(),
      idempotencyKey: nextId(),
      traceId: nextId(),
      actionId: 'cancel',
      actionPayload: const {'reason': 'apology_voice_declined'},
    );
    final command = _cancellation!;
    final run = gateway.start(command);
    _cancelling = run;
    var acknowledged = false;
    try {
      await for (final event in run.events.timeout(
        const Duration(seconds: 30),
      )) {
        if (!current()) throw StateError('Session changed');
        if (event.kind == AgentEventKind.error) {
          throw StateError('Cancellation failed');
        }
        if (event.eventName == 'task_cancelled' &&
            event.sessionId == command.sessionId &&
            event.payload['commandId'] == command.commandId) {
          acknowledged = true;
        }
      }
      if (!acknowledged) throw StateError('Cancellation not acknowledged');
    } finally {
      run.cancel();
      if (identical(_cancelling, run)) _cancelling = null;
    }
  }

  void close() {
    voice.close();
    _cancelling?.cancel();
  }
}
