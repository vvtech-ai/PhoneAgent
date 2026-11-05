import 'package:phone_agent/features/conversation/domain/confirmation/call_confirmation_policy.dart';
import 'package:phone_agent/features/conversation/domain/confirmation/call_confirmation_reply.dart';

/// Explicit external-model boundary for tests of the existing call workflow.
class ConfirmationReplyStub implements CallConfirmationReplyRepository {
  const ConfirmationReplyStub({
    this.decisions = const {},
    this.defaultDecision = CallReplyDecision.confirm,
  });
  final Map<String, CallReplyDecision> decisions;
  final CallReplyDecision defaultDecision;

  @override
  Future<CallReply> classify(CallReplyScope scope, String text) async =>
      CallReply(decisions[text] ?? defaultDecision);
}
