import 'call_confirmation_policy.dart';

typedef CallReplyScope = ({
  String accountId,
  String sessionId,
  String toolId,
  String specSignature,
  int generation,
  String cardText,
});

class CallReply {
  const CallReply(this.decision, [this.answer = '']);
  final CallReplyDecision decision;
  final String answer;
}

abstract interface class CallConfirmationReplyRepository {
  Future<CallReply> classify(CallReplyScope scope, String text);
}
