import 'dart:convert';
import '../../../calls/domain/call_launch_request.dart';
import '../conversation_messages.dart';
import '../call_confirmation.dart';

/// A visible card can acknowledge only the same current request specification.
abstract final class CurrentCallConfirmationGate {
  static bool matches({
    required ConversationMessage message,
    required CallLaunchRequest? request,
    required List<ConversationMessage> messages,
  }) {
    if (request == null ||
        message.confirmation == null ||
        request.toolId.isEmpty ||
        message.toolCallId != request.toolId ||
        _signature(_displaySpec(message.confirmation!)) !=
            _signature(_displaySpec(request.confirmation))) {
      return false;
    }
    final index = messages.indexWhere((m) => m.id == message.id);
    if (index < 0) return false;
    return !messages
        .skip(index + 1)
        .any(
          (m) =>
              m.confirmation != null ||
              m.batchConfirmation != null ||
              m.receipt != null ||
              m.batchReceipt != null,
        );
  }

  static Map<String, Object?> _displaySpec(CallConfirmation value) => {
    ...value.sourceSpec,
    'targetName': value.targetName,
    'phoneNumber': value.phoneNumber,
    'primaryGoal': value.primaryGoal,
    'summaryLines': value.sourceSpec['summaryLines'] ?? value.summaryLines,
    if (value.fromBatchTool || value.sourceSpec.containsKey('recipientsJson'))
      'recipientCount': value.recipientCount,
  };

  static String _signature(Object? value) => jsonEncode(_canonical(value));
  static Object? _canonical(Object? value) {
    if (value is Map) {
      final keys = value.keys.cast<String>().toList()..sort();
      return {for (final key in keys) key: _canonical(value[key])};
    }
    if (value is List) return value.map(_canonical).toList();
    return value;
  }
}
