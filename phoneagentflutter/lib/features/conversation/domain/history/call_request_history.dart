import '../../../calls/domain/call_launch_request.dart';
import '../conversation_messages.dart';
import 'ledger_event.dart';

/// Reconstructs identity context only; never schedules restored requests.
abstract final class CallRequestHistory {
  static List<CallLaunchRequest> project(
    String sessionId,
    Iterable<LedgerEvent> facts,
  ) {
    final messages = ConversationMessages.project(
      facts,
    ).where((m) => m.confirmation != null);
    final requests = <CallLaunchRequest>[];
    for (final message in messages) {
      final confirmation = message.confirmation!;
      final source = facts
          .where(
            (f) =>
                f.type == 'TOOL_REQUESTED' &&
                f.payload['toolCallId'] == message.toolCallId,
          )
          .lastOrNull;
      final args = ConversationMessages.object(source?.payload['arguments']);
      final request = CallLaunchRequest(
        sessionId: sessionId,
        toolId: message.toolCallId ?? '',
        commandId: message.commandId ?? '',
        ordinal: requests.length + 1,
        spec: {
          ...args,
          'targetName': confirmation.targetName,
          'phoneNumber': confirmation.phoneNumber,
          'primaryGoal': confirmation.primaryGoal,
          'summaryLines': args['summaryLines'] ?? confirmation.summaryLines,
          if (source?.payload['toolName'] == 'makeBatchCalls')
            'recipientCount': confirmation.recipientCount,
        },
      );
      if (request.isValid) requests.add(request);
    }
    return requests;
  }
}
