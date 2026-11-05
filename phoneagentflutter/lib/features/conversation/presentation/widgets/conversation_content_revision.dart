import 'package:flutter/foundation.dart';
import '../../domain/conversation_messages.dart';
import 'conversation_confirmation_values.dart';
import 'conversation_receipt_values.dart';
import 'conversation_option_values.dart';

/// Local presentation snapshot. Equality uses values, never model identity.
/// Local expansion and recording reveal retain their independent owners.
class ConversationContentRevision {
  ConversationContentRevision(
    String session,
    List<ConversationMessage> messages, {
    String liveTranscript = '',
    Iterable<Object?> precheckValues = const [],
  }) : _values = List<Object?>.unmodifiable([
         session,
         liveTranscript,
         ...precheckValues,
         messages.length,
         for (final message in messages) ...[
           message.id,
           message.role,
           message.text,
           message.thinking?.text,
           message.thinking?.processing,
           message.toolCard?.id,
           message.toolCard?.toolName,
           message.toolCard?.methodLabel,
           message.toolCard?.body,
           message.toolCard?.result,
           message.toolCard?.status,
           ...conversationConfirmationValues(message),
           ...conversationReceiptValues(message),
           ...conversationOptionValues(message),
         ],
       ]);
  final List<Object?> _values;

  @override
  bool operator ==(Object other) =>
      other is ConversationContentRevision &&
      listEquals(_values, other._values);

  @override
  int get hashCode => Object.hashAll(_values);
}
