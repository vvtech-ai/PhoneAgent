import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/calls/data/preview_call_flow.dart';
import 'package:phone_agent/features/conversation/domain/confirmation/call_confirmation_policy.dart';
import 'package:phone_agent/features/conversation/domain/confirmation/call_confirmation_reply.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_controller.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_state.dart';

import '../../support/confirm_rendered_call.dart';

class _Reply implements CallConfirmationReplyRepository {
  final result = Completer<CallReply>();
  @override
  Future<CallReply> classify(CallReplyScope scope, String text) =>
      result.future;
}

void main() {
  // Keep the original normal and conflicting utterances at the real flow boundary.
  for (final (text, decision) in [
    ('确认拨打', CallReplyDecision.confirm),
    ('好，确认拨打。', CallReplyDecision.confirm),
    ('好的', CallReplyDecision.confirm),
    ('没问题', CallReplyDecision.confirm),
    ('就直接打吧', CallReplyDecision.confirm),
    ('确认拨打，但是改成明天', CallReplyDecision.edit),
    ('好的，先不要打', CallReplyDecision.cancel),
    ('现在拨打吗？', CallReplyDecision.question),
    ('如果可以就确认拨打', CallReplyDecision.unclear),
    ('确认，等一下', CallReplyDecision.wait),
  ]) {
    testWidgets('current card applies semantic $decision for $text', (
      tester,
    ) async {
      final ports = PreviewCallFlow(CallFlowScenario.single);
      final reply = _Reply();
      final controller = ConversationController(
        entry: const ConversationEntry(sessionId: 'mock-call-flow'),
        accountId: 'synthetic',
        gateway: ports,
        history: ports,
        callAdmission: ports.admission,
        callSessions: ports,
        confirmationReplies: reply,
      );
      addTearDown(controller.dispose);
      controller.send('合成需求');
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump();
      markCallCardPresented(controller);
      controller.send(text);
      expect(controller.state.preparingCall, isFalse);
      expect(ports.commands, hasLength(1));
      reply.result.complete(CallReply(decision));
      await tester.pump();
      if (decision == CallReplyDecision.confirm) {
        expect(controller.state.preparingCall, isTrue);
        await tester.pump(const Duration(milliseconds: 1499));
        expect(ports.commands, hasLength(1));
        await tester.pump(const Duration(milliseconds: 1));
        await tester.pump();
        expect(ports.commands, hasLength(2));
        expect(ports.commands.last.actionId, 'confirm_call');
      } else if ({
        CallReplyDecision.edit,
        CallReplyDecision.cancel,
      }.contains(decision)) {
        expect(ports.commands, hasLength(2));
        expect(ports.commands.last.message, text);
        expect(ports.commands.last.actionId, isNull);
      } else {
        expect(ports.commands, hasLength(1));
        expect(controller.state.preparingCall, isFalse);
        expect(controller.calls!.snapshot.launch.request, isNotNull);
      }
      controller.close();
    });
  }
}
