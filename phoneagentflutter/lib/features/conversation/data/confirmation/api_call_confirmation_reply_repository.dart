import '../../../../core/network/account_api.dart';
import '../../../../core/network/account_session.dart';
import '../../domain/confirmation/call_confirmation_policy.dart';
import '../../domain/confirmation/call_confirmation_reply.dart';
import '../../domain/conversation_ids.dart';

class ApiCallConfirmationReplyRepository
    implements CallConfirmationReplyRepository {
  const ApiCallConfirmationReplyRepository(this.api);
  final AccountApi api;
  static const _decisions = {
    'CONFIRM': CallReplyDecision.confirm,
    'EDIT': CallReplyDecision.edit,
    'CANCEL': CallReplyDecision.cancel,
    'NEW_REQUEST': CallReplyDecision.newRequest,
    'QUESTION': CallReplyDecision.question,
    'WAIT': CallReplyDecision.wait,
    'UNCLEAR': CallReplyDecision.unclear,
  };

  @override
  Future<CallReply> classify(CallReplyScope scope, String text) async {
    if (text.length > 500) {
      throw ApiFailure.invalidResponse;
    }
    final value = await api.request(
      'api/agent/call-confirmation/reply',
      method: 'POST',
      body: {
        'userId': scope.accountId,
        'sessionId': scope.sessionId,
        'pendingToolCallId': scope.toolId,
        // Compatibility hint only; the server reads the full card by identity.
        'cardText': scope.cardText.length > 1500
            ? scope.cardText.substring(0, 1500)
            : scope.cardText,
        'userText': text,
        'replyId': newConversationId(),
      },
    );
    if (value is! Map || !_decisions.containsKey(value['decision'])) {
      throw ApiFailure.invalidResponse;
    }
    final answer = value['answer'] ?? '';
    if (answer is! String ||
        answer.length > 160 ||
        answer.contains('\n') ||
        answer.contains('\r')) {
      throw ApiFailure.invalidResponse;
    }
    final decision = _decisions[value['decision']]!;
    if (value['unavailable'] == true) {
      return const CallReply(CallReplyDecision.unclear, '', true);
    }
    return CallReply(
      decision,
      decision == CallReplyDecision.question ? answer : '',
    );
  }
}
