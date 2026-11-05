import 'dart:convert';
import 'conversation_questions.dart';
import 'conversation_thinking.dart';
import 'artifacts/task_artifact.dart';
import 'artifacts/task_artifact_projection.dart';
import 'artifacts/batch_artifact_presentation.dart';
import 'confirmation/confirmation_supplement_messages.dart';
import 'confirmation/call_confirmation_prompt.dart';
import 'restaurant_option_presentation.dart';
import '../../attachments/domain/user_document_presentation.dart';
import 'history/ledger_event.dart';
import 'membership_denial_reply.dart';
import 'conversation_tool_card.dart';
import 'conversation_message_presentation.dart';
import 'call_confirmation.dart';
import 'batch_confirmation.dart';
import 'history/batch_confirmation_projector.dart';
import 'receipts/call_receipt.dart';
import 'receipts/call_receipt_projector.dart';
import 'receipts/batch_receipt.dart';
import 'receipts/batch_receipt_projector.dart';

enum MessageRole { user, assistant, notice }

class ConversationOption {
  const ConversationOption(
    this.label,
    this.detail, {
    this.restaurant,
    this.phone = '',
    this.isContact = false,
  });
  final String label, detail;
  final String phone;
  final bool isContact;
  final RestaurantOptionPresentation? restaurant;
}

class ConversationMessage {
  const ConversationMessage({
    required this.id,
    required this.role,
    required this.text,
    this.commandId,
    this.toolCallId,
    this.options = const [],
    this.optionsLocked = false,
    this.selectedOptionIndex,
    this.optionsTitleVisible = true,
    this.transient = false,
    this.toolCard,
    this.confirmation,
    this.batchConfirmation,
    this.receipt,
    this.batchReceipt,
    this.document,
    this.artifact,
    this.questions,
    this.questionSourceText,
    this.thinking,
    this.insertBeforeCommandId,
  });
  final String id, text;
  final String? commandId, toolCallId;
  final MessageRole role;
  final List<ConversationOption> options;

  /// Keeps a completed local choice card visible without allowing another tap.
  final bool optionsLocked;
  final int? selectedOptionIndex;
  final bool optionsTitleVisible;
  final bool transient;
  final ConversationToolCard? toolCard;
  final CallConfirmation? confirmation;
  final BatchConfirmation? batchConfirmation;
  final CallReceipt? receipt;
  final BatchReceipt? batchReceipt;
  final UserDocumentPresentation? document;
  final TaskArtifact? artifact;
  final ConversationQuestions? questions;
  final ConversationThinking? thinking;

  /// Presentation-only anchor for a local record that belongs immediately
  /// before a durable command turn. It is never sent to the server.
  final String? insertBeforeCommandId;

  /// Original live/durable ASK_USER preamble, used only for display reconciliation.
  final String? questionSourceText;

  ConversationMessage copyWith({
    String? id,
    String? text,
    String? commandId,
    List<ConversationOption>? options,
    bool? optionsLocked,
    int? selectedOptionIndex,
    bool? optionsTitleVisible,
    bool? transient,
    String? insertBeforeCommandId,
    bool clearConfirmation = false,
  }) => ConversationMessage(
    id: id ?? this.id,
    role: role,
    text: text ?? this.text,
    commandId: commandId ?? this.commandId,
    toolCallId: toolCallId,
    options: options ?? this.options,
    optionsLocked: optionsLocked ?? this.optionsLocked,
    selectedOptionIndex: selectedOptionIndex ?? this.selectedOptionIndex,
    optionsTitleVisible: optionsTitleVisible ?? this.optionsTitleVisible,
    transient: transient ?? this.transient,
    toolCard: toolCard,
    confirmation: clearConfirmation ? null : confirmation,
    batchConfirmation: batchConfirmation,
    receipt: receipt,
    batchReceipt: batchReceipt,
    document: document,
    artifact: artifact,
    questions: questions,
    thinking: thinking,
    questionSourceText: questionSourceText,
    insertBeforeCommandId: insertBeforeCommandId ?? this.insertBeforeCommandId,
  );
}

class ConversationMessages {
  static Set<String> rejectedCallIds(Iterable<LedgerEvent> facts) {
    final rejected = <String>{};
    final ordered = facts.toList()
      ..sort((a, b) => a.sequence.compareTo(b.sequence));
    for (final event in ordered) {
      if (event.schemaVersion != 1 ||
          !const {
            'makeCall',
            'makeBatchCalls',
            'confirmBatchTask',
          }.contains(text(event.payload, 'toolName'))) {
        continue;
      }
      final id = text(event.payload, 'toolCallId').trim();
      if (id.isEmpty) continue;
      if (event.type == 'TOOL_REQUESTED') rejected.remove(id);
      if (event.type == 'TOOL_RESULT_RECORDED' &&
          const {
            'rejected',
            'policy_rejected',
          }.contains(text(event.payload, 'resultStatus').toLowerCase())) {
        rejected.add(id);
      }
    }
    return rejected;
  }

  static String text(Map<String, Object?> map, String key) =>
      map[key] is String ? map[key] as String : '';

  /// Reads the first non-blank textual alias from a wire payload.
  ///
  /// Contact candidates have historically used both `phone` and
  /// `phoneNumber`; keeping the alias handling here prevents presentation
  /// code from silently dropping a number when the server sends the latter.
  static String firstText(Map<String, Object?> map, Iterable<String> keys) {
    for (final key in keys) {
      final value = text(map, key).trim();
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  static Map<String, Object?> object(Object? value) {
    if (value is String) {
      try {
        value = jsonDecode(value);
      } on FormatException {
        return const {};
      }
    }
    if (value is Map) {
      return {
        for (final entry in value.entries)
          if (entry.key is String) entry.key as String: entry.value,
      };
    }
    return const {};
  }

  /// ASK_USER payloads may use the normalized `questions` container or the
  /// legacy top-level `items`, `questionsJson`, and `question` fields.
  static Map<String, Object?> questionPayload(Map<String, Object?> payload) {
    final nested = object(payload['questions']);
    if (nested.isNotEmpty) return nested;
    final arguments = object(payload['arguments']);
    if (arguments.isNotEmpty) {
      final nestedArguments = object(arguments['questions']);
      if (nestedArguments.isNotEmpty) return nestedArguments;
      if (arguments.containsKey('items') ||
          arguments.containsKey('questionsJson') ||
          arguments.containsKey('question') ||
          arguments.containsKey('title')) {
        return arguments;
      }
    }
    if (payload.containsKey('items') ||
        payload.containsKey('questionsJson') ||
        payload.containsKey('question') ||
        payload.containsKey('title')) {
      return object(payload);
    }
    return const {};
  }

  static List<Object?> array(Object? value) {
    if (value is String) {
      try {
        value = jsonDecode(value);
      } catch (_) {
        return const [];
      }
    }
    return value is List ? value : const [];
  }

  static List<ConversationOption> options(Map<String, Object?> data) =>
      List.unmodifiable(
        array(
          data['items'] ?? data['optionsJson'],
        ).map(object).where((m) => text(m, 'label').isNotEmpty).map((m) {
          final phone = firstText(m, const ['phone', 'phoneNumber']);
          return ConversationOption(
            text(m, 'label'),
            [
              text(m, 'detail').trim(),
              phone,
              text(m, 'address').trim(),
              RestaurantOptionPresentation.optionDistanceText(
                m['distanceMeters'],
              ),
            ].where((v) => v.isNotEmpty).toSet().join(' | '),
            restaurant: RestaurantOptionPresentation.from(m),
            phone: phone,
            isContact:
                m['tags'] is List &&
                (m['tags'] as List).whereType<String>().any(
                  (tag) => tag.trim().toLowerCase() == 'contact',
                ),
          );
        }),
      );
  static String questions(Map<String, Object?> data, {String fallback = ''}) =>
      ConversationQuestions.displayText(data, fallback: fallback);

  static List<ConversationMessage> project(Iterable<LedgerEvent> facts) {
    final events = facts.toList()
      ..sort((a, b) => a.sequence.compareTo(b.sequence));
    final superseded = <String>{};
    final committed = <String>{};
    for (final e in events) {
      if (e.schemaVersion != 1) continue;
      if (e.type == 'ASSISTANT_TURN_COMMITTED' && e.commandId != null) {
        committed.add(e.commandId!);
      }
      if (e.type == 'RUN_CANCELLED' &&
          text(e.payload, 'stage') == 'recovery_revision') {
        final command = e.commandId;
        if (command != null && !committed.contains(command)) {
          superseded.add(command);
        }
      }
    }
    final receipts = <String, List<ProjectedCallReceipt>>{};
    for (final receipt in CallReceiptProjector.project(
      events.where((e) => !superseded.contains(e.commandId)),
    )) {
      if (receipt.receipt.isRunning) continue;
      receipts.putIfAbsent(receipt.anchor.eventId, () => []).add(receipt);
    }
    final result = <ConversationMessage>[];
    final eligible = events
        .where((e) => !superseded.contains(e.commandId))
        .toList();
    final confirmations = {
      for (final item in BatchConfirmationProjector.project(eligible))
        item.anchor.eventId: item,
    };
    final executionRequests = BatchConfirmationProjector.executionRequestIds(
      eligible,
    );
    final batches = <String, List<ProjectedBatchReceipt>>{};
    for (final batch in BatchReceiptProjector.project(
      events.where((e) => !superseded.contains(e.commandId)),
    )) {
      batches.putIfAbsent(batch.anchor.eventId, () => []).add(batch);
    }
    final confirmationTurns = <String, int>{};
    var userTurn = 0;
    for (final e in events) {
      if (e.schemaVersion != 1 || superseded.contains(e.commandId)) continue;
      if (e.type == 'USER_TURN_ACCEPTED') userTurn++;
      for (final message in TaskArtifactProjection.fromEvent(e)) {
        final index = result.indexWhere((m) => m.id == message.id);
        if (index < 0) {
          result.add(message);
        } else {
          result[index] = message;
        }
      }
      if (e.type == 'CALL_CONFIRMATION_SUPPLEMENT') {
        result.addAll(ConfirmationSupplementMessages.fromEvent(e));
        continue;
      }
      if (confirmations[e.eventId] case final item?) {
        result.add(
          ConversationMessage(
            id: 'ledger:batch-confirmation:${item.confirmation.snapshotId}',
            role: MessageRole.assistant,
            text: item.confirmation.assistantText,
            commandId: e.commandId,
            toolCallId: item.confirmation.snapshotId,
            batchConfirmation: item.confirmation,
          ),
        );
      }
      for (final batch in batches[e.eventId] ?? <ProjectedBatchReceipt>[]) {
        result.add(
          ConversationMessage(
            id: 'ledger:batch:${batch.receipt.id}',
            role: MessageRole.assistant,
            text: '',
            commandId: e.commandId,
            batchReceipt: batch.receipt,
          ),
        );
      }
      for (final projection
          in receipts[e.eventId] ?? <ProjectedCallReceipt>[]) {
        result.add(
          ConversationMessage(
            id: 'ledger:call:${projection.receipt.attemptId}',
            role: MessageRole.assistant,
            text: '',
            commandId: e.commandId,
            receipt: projection.receipt,
          ),
        );
      }
      final p = e.payload;
      final toolId = text(p, 'toolCallId').trim();
      final callTool = const {
        'makeCall',
        'makeBatchCalls',
      }.contains(text(p, 'toolName'));
      if (e.type == 'TOOL_RESULT_RECORDED' &&
          callTool &&
          const {
            'rejected',
            'policy_rejected',
          }.contains(text(p, 'resultStatus').toLowerCase()) &&
          toolId.isNotEmpty) {
        result.removeWhere(
          (m) => m.confirmation != null && m.toolCallId == toolId,
        );
        continue;
      }
      if (e.type == 'TOOL_REQUESTED' && callTool) {
        if (executionRequests.contains(e.eventId)) continue;
        final confirmation = CallConfirmation.fromPayload(
          object(p['arguments']),
          batch: text(p, 'toolName') == 'makeBatchCalls',
        );
        if (confirmation.hasContent) {
          final id = toolId.isEmpty
              ? 'ledger:${e.eventId}'
              : 'ledger:call-confirmation:$toolId';
          final message = ConversationMessage(
            id: id,
            role: MessageRole.assistant,
            text: '',
            commandId: e.commandId,
            toolCallId: toolId.isEmpty ? null : toolId,
            confirmation: confirmation,
          );
          final index = result.indexWhere((m) => m.id == id);
          if (index < 0) {
            final promptIndex = result.indexWhere((m) => m.id == '$id:prompt');
            result.insert(
              promptIndex < 0 ? result.length : promptIndex,
              message,
            );
            confirmationTurns[id] = userTurn;
          } else if (confirmationTurns[id] == userTurn) {
            result[index] = message;
          }
          final prompt = CallConfirmationPrompt.fromRequest(e, id, toolId);
          if (!result.any((m) => m.id == prompt.id)) result.add(prompt);
        }
        continue;
      }
      UserDocumentPresentation? document;
      var content = '';
      var role = MessageRole.assistant;
      var choices = const <ConversationOption>[];
      if (e.type == 'USER_TURN_ACCEPTED') {
        role = MessageRole.user;
        if (text(p, 'inputKind') == 'document') {
          document = UserDocumentPresentation.fromTurnText(text(p, 'text'));
        }
        content = text(p, 'inputKind') == 'document'
            ? '已上传文档'
            : text(p, 'text');
      } else if (e.type == 'ASSISTANT_TURN_COMMITTED') {
        content = BatchReceiptProjector.pointsNotice(e) ?? text(p, 'text');
      } else if (e.type == 'MEMORY_OPERATION_NOTICE') {
        content = text(p, 'text');
      } else if (e.type == 'RUN_FAILED') {
        content = MembershipDenialReply.message(p['reason']) ?? '';
        if (p['reason'] == 'BATCH_CONTACT_LIMIT' && e.commandId != null) {
          result.removeWhere(
            (m) =>
                m.commandId == e.commandId &&
                m.confirmation?.fromBatchTool == true,
          );
        }
      } else if (e.type == 'TOOL_REQUESTED' &&
          p['displayPayloadVersion'] == 1) {
        final args = object(p['arguments']);
        switch (text(p, 'toolName')) {
          case 'showOptions':
            choices = options(args);
            content = text(args, 'title');
            if (content.isEmpty && choices.isNotEmpty) content = '请选择';
          case 'askUser':
            content = questions(args);
          case 'requestPermission':
            content = text(args, 'reason');
          case 'importDocument':
            content = text(args, 'reason');
        }
      }
      final questionnaire =
          e.type == 'TOOL_REQUESTED' &&
              text(p, 'toolName') == 'askUser' &&
              p['displayPayloadVersion'] == 1
          ? ConversationQuestions.parse(object(p['arguments']))
          : null;
      if (content.isNotEmpty || choices.isNotEmpty || questionnaire != null) {
        result.add(
          ConversationMessage(
            id: e.type == 'MEMORY_OPERATION_NOTICE'
                ? 'ledger:memory-notice:${e.eventId}'
                : 'ledger:${e.eventId}',
            role: role,
            text: content,
            commandId: e.commandId,
            options: choices,
            document: document,
            questions: questionnaire,
            questionSourceText:
                e.type == 'TOOL_REQUESTED' && text(p, 'toolName') == 'askUser'
                ? text(p, 'assistantText')
                : null,
            toolCallId: text(p, 'toolCallId').isEmpty
                ? null
                : text(p, 'toolCallId'),
          ),
        );
      }
    }
    return BatchArtifactPresentation.project(
      ConversationMessagePresentation.project(
        result.where((message) {
          if (message.role != MessageRole.assistant ||
              message.text.trim().isEmpty ||
              message.batchConfirmation != null ||
              message.confirmation != null ||
              message.toolCard != null ||
              message.receipt != null ||
              message.batchReceipt != null ||
              message.options.isNotEmpty ||
              message.questions != null ||
              message.artifact != null ||
              message.document != null) {
            return true;
          }
          return !result.any(
            (card) =>
                card.commandId != null &&
                card.commandId == message.commandId &&
                card.batchConfirmation?.decision ==
                    BatchConfirmationDecision.confirmed &&
                card.batchConfirmation!.assistantText.trim() ==
                    message.text.trim(),
          );
        }),
      ),
    );
  }
}
