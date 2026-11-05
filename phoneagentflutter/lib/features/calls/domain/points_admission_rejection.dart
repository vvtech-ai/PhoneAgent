import '../../conversation/domain/agent_protocol.dart';
import '../../conversation/domain/conversation_messages.dart';

/// Only live, structured admission results may invalidate a wallet snapshot.
abstract final class PointsAdmissionRejection {
  static bool matches(AgentEvent event) {
    if (event.kind != AgentEventKind.signal &&
        event.kind != AgentEventKind.finalResponse) {
      return false;
    }
    final payload = event.payload;
    final call = ConversationMessages.object(payload['callResult']);
    final metadata = ConversationMessages.object(call['metadata']);
    final batch = ConversationMessages.object(payload['batchCallResult']);
    return payload['type'] == 'CALL_RESULT' &&
            metadata['resultCode'] == 'POINTS_INSUFFICIENT_BALANCE' ||
        payload['type'] == 'BATCH_CALL_RESULT' &&
            batch['resultCode'] == 'POINTS_INSUFFICIENT_BALANCE';
  }
}
