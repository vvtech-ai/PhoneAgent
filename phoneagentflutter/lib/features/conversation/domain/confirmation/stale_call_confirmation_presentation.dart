import 'dart:convert';
import '../conversation_messages.dart';
import 'call_confirmation_prompt.dart';

/// Display projection only; ledger facts and call authorization stay untouched.
abstract final class StaleCallConfirmationPresentation {
  static List<ConversationMessage> project(List<ConversationMessage> messages) {
    final visible = <ConversationMessage>[];
    ConversationMessage? prior;
    var terminal = false;
    for (final message in messages) {
      if (message.role == MessageRole.user) terminal = false;
      if (terminal && prior != null && _stale(message, prior)) continue;
      visible.add(message);
      final confirmation = message.confirmation;
      if (confirmation != null) {
        prior = confirmation.fromBatchTool || confirmation.isBatch
            ? null
            : message;
        terminal = false;
      } else if (message.batchConfirmation != null) {
        prior = null;
        terminal = false;
      } else if (message.receipt != null &&
          _terminal(message.receipt!.status)) {
        terminal = true;
      }
    }
    return List.unmodifiable(visible);
  }

  static bool _stale(ConversationMessage message, ConversationMessage prior) {
    if (message.role != MessageRole.assistant ||
        message.receipt != null ||
        message.batchReceipt != null ||
        message.batchConfirmation != null ||
        message.toolCard != null ||
        message.options.isNotEmpty ||
        message.questions != null ||
        message.artifact != null ||
        message.document != null) {
      return false;
    }
    final tool = message.toolCallId?.trim() ?? '';
    final oldTool = prior.toolCallId?.trim() ?? '';
    if (tool.isNotEmpty && tool != oldTool) return false;
    final text = message.text.trim(), oldText = prior.text.trim();
    final sameText =
        text == CallConfirmationPrompt.text ||
        (oldText.isNotEmpty && text == oldText);
    if (message.confirmation case final confirmation?) {
      return tool.isNotEmpty &&
          oldTool == tool &&
          !confirmation.fromBatchTool &&
          !confirmation.isBatch &&
          (text.isEmpty || sameText) &&
          jsonEncode(_canonical(confirmation.sourceSpec)) ==
              jsonEncode(_canonical(prior.confirmation!.sourceSpec));
    }
    return text.isNotEmpty && sameText;
  }

  static Object? _canonical(Object? value) {
    if (value is Map<String, Object?>) {
      final keys = value.keys.toList()..sort();
      return {for (final key in keys) key: _canonical(value[key])};
    }
    if (value is List) return value.map(_canonical).toList();
    return value;
  }

  static bool _terminal(String status) {
    final value = status.trim().toUpperCase();
    return const {
          'COMPLETED',
          'SUCCESS',
          'DONE',
          'FINISHED',
          'ENDED',
          'FAILED',
          'INCOMPLETE',
          'PARTIAL',
          'PARTIALLY_COMPLETED',
          'NEEDS_FOLLOW_UP',
          'EXECUTION_ERROR',
          'UNCLEAR',
          'CANCELLED',
          'CANCELED',
          'REJECTED',
          'NOT_FOUND',
          'NO_ANSWER',
          'MISSED_CALL',
          'TIMEOUT',
          'USER_CANCELLED',
          'USER_CANCELED',
          'TERMINATED',
        }.contains(value) ||
        const [
          'COMPLETED',
          'FAILED',
          'CANCELLED',
          'CANCELED',
          'REJECTED',
          'NOT_FOUND',
          'NO_ANSWER',
          'MISSED_CALL',
          'TIMEOUT',
          'ENDED',
          'TERMINATED',
        ].any(value.contains);
  }
}
