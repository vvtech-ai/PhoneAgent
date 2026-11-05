import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/calls/data/preview_call_flow.dart';
import 'package:phone_agent/features/calls/domain/call_launch_coordinator.dart';
import 'package:phone_agent/features/contacts/domain/contact_name_matcher.dart';
import 'package:phone_agent/features/conversation/domain/confirmation/call_confirmation_policy.dart';
import 'package:phone_agent/features/conversation/domain/confirmation/call_confirmation_reply.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_controller.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_state.dart';

import '../../support/confirm_rendered_call.dart';

class _SemanticReplies implements CallConfirmationReplyRepository {
  final inputs = <String>[];
  final pending = <Completer<CallReply>>[];

  @override
  Future<CallReply> classify(CallReplyScope scope, String text) {
    inputs.add(text);
    final result = Completer<CallReply>();
    pending.add(result);
    return result.future;
  }
}

void main() {
  testWidgets(
    'unavailable classification preserves card without a misleading supplement and can be retried',
    (tester) async {
      final ports = PreviewCallFlow(CallFlowScenario.single);
      final replies = _SemanticReplies();
      final controller = ConversationController(
        entry: const ConversationEntry(sessionId: 'mock-call-flow'),
        accountId: 'synthetic',
        gateway: ports,
        history: ports,
        callAdmission: ports.admission,
        callSessions: ports,
        confirmationReplies: replies,
      );
      addTearDown(controller.dispose);
      controller.send('合成任务');
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump();
      markCallCardPresented(controller);
      final request = controller.calls!.snapshot.launch.request;
      controller.send('是的。');
      replies.pending.last.complete(
        const CallReply(CallReplyDecision.unclear, '', true),
      );
      await tester.pump();
      expect(controller.calls!.snapshot.launch.request, same(request));
      expect(controller.state.preparingCall, isFalse);
      expect(ports.commands, hasLength(1));
      controller.send('是的。');
      replies.pending.last.complete(const CallReply(CallReplyDecision.confirm));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pump();
      expect(ports.commands, hasLength(2));
      expect(ports.commands.last.pendingToolCallId, request!.toolId);
      controller.close();
    },
  );
  for (final decision in [
    CallReplyDecision.question,
    CallReplyDecision.wait,
    CallReplyDecision.unclear,
  ]) {
    testWidgets('$decision keeps the original card for a later confirmation', (
      tester,
    ) async {
      final ports = PreviewCallFlow(CallFlowScenario.single);
      final replies = _SemanticReplies();
      final controller = ConversationController(
        entry: const ConversationEntry(sessionId: 'mock-call-flow'),
        accountId: 'synthetic',
        gateway: ports,
        history: ports,
        callAdmission: ports.admission,
        callSessions: ports,
        confirmationReplies: replies,
      );
      addTearDown(controller.dispose);
      controller.send('合成任务');
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump();
      markCallCardPresented(controller);
      final request = controller.calls!.snapshot.launch.request;
      controller.send('先核对一下');
      replies.pending.last.complete(CallReply(decision));
      await tester.pump();
      expect(controller.calls!.snapshot.launch.request, same(request));
      expect(controller.state.preparingCall, isFalse);
      expect(ports.commands, hasLength(1));

      controller.send('确定。');
      replies.pending.last.complete(const CallReply(CallReplyDecision.confirm));
      await tester.pump();
      expect(controller.state.preparingCall, isTrue);
      expect(controller.send('确定。'), isFalse);
      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pump();
      expect(ports.commands, hasLength(2));
      expect(ports.commands.last.pendingToolCallId, request!.toolId);
      expect(replies.inputs, ['先核对一下', '确定。']);
      controller.close();
    });
  }

  testWidgets(
    'new input pauses preparation while its semantic result is pending',
    (tester) async {
      final ports = PreviewCallFlow(CallFlowScenario.single);
      final replies = _SemanticReplies();
      final controller = ConversationController(
        entry: const ConversationEntry(sessionId: 'mock-call-flow'),
        accountId: 'synthetic',
        gateway: ports,
        history: ports,
        callAdmission: ports.admission,
        callSessions: ports,
        confirmationReplies: replies,
      );
      addTearDown(controller.dispose);
      controller.send('合成任务');
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump();
      confirmRenderedCall(controller);
      expect(controller.state.preparingCall, isTrue);
      controller.send('等等，我要核对号码');
      expect(controller.state.preparingCall, isFalse);
      await tester.pump(const Duration(seconds: 2));
      expect(ports.commands, hasLength(1));
      replies.pending.single.complete(const CallReply(CallReplyDecision.wait));
      await tester.pump();
      expect(ports.commands, hasLength(1));
      controller.close();
    },
  );

  testWidgets(
    'a late semantic confirmation cannot authorize a replacement card',
    (tester) async {
      final ports = PreviewCallFlow(CallFlowScenario.single);
      final replies = _SemanticReplies();
      final controller = ConversationController(
        entry: const ConversationEntry(sessionId: 'mock-call-flow'),
        accountId: 'synthetic',
        gateway: ports,
        history: ports,
        callAdmission: ports.admission,
        callSessions: ports,
        confirmationReplies: replies,
      );
      addTearDown(controller.dispose);
      controller.send('合成任务');
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump();
      markCallCardPresented(controller);
      controller.send('确定。');
      controller.calls!.receive(
        sessionId: 'mock-call-flow',
        commandId: 'new-command',
        toolId: 'replacement-card',
        spec: {
          'targetName': '新合成目标',
          'phoneNumber': '000',
          'primaryGoal': '更新任务',
        },
      );
      markCallCardPresented(controller);
      replies.pending.single.complete(
        const CallReply(CallReplyDecision.confirm),
      );
      await tester.pump(const Duration(seconds: 2));
      expect(controller.state.preparingCall, isFalse);
      expect(ports.commands, hasLength(1));
      expect(
        controller.calls!.snapshot.launch.request!.toolId,
        'replacement-card',
      );
      controller.close();
    },
  );

  for (final source in ContactInputSource.values) {
    for (final text in ['确认拨打', '确定。', '我没说现在拨打', '随便']) {
      testWidgets('$source $text awaits semantic decision before preparation', (
        tester,
      ) async {
        final ports = PreviewCallFlow(CallFlowScenario.single);
        final replies = _SemanticReplies();
        final controller = ConversationController(
          entry: const ConversationEntry(sessionId: 'mock-call-flow'),
          accountId: 'synthetic',
          gateway: ports,
          history: ports,
          callAdmission: ports.admission,
          callSessions: ports,
          confirmationReplies: replies,
        );
        addTearDown(controller.dispose);
        controller.send('合成任务');
        await tester.pump(const Duration(milliseconds: 1));
        await tester.pump();
        markCallCardPresented(controller);
        final originalTool = controller.calls!.snapshot.launch.request!.toolId;

        expect(controller.send(text, source: source), isTrue);
        expect(replies.inputs, [text]);
        expect(
          controller.calls!.snapshot.launch.phase,
          CallLaunchPhase.awaitingConfirmation,
        );
        await tester.pump(const Duration(seconds: 2));
        expect(ports.commands, hasLength(1));
        replies.pending.single.complete(
          const CallReply(CallReplyDecision.wait),
        );
        await tester.pump();
        expect(ports.commands, hasLength(1));
        expect(controller.calls!.snapshot.launch.request!.toolId, originalTool);
        controller.close();
      });
    }
  }

  testWidgets('semantic confirmation is not vetoed by local phrase matching', (
    tester,
  ) async {
    final ports = PreviewCallFlow(CallFlowScenario.single);
    final replies = _SemanticReplies();
    final controller = ConversationController(
      entry: const ConversationEntry(sessionId: 'mock-call-flow'),
      accountId: 'synthetic',
      gateway: ports,
      history: ports,
      callAdmission: ports.admission,
      callSessions: ports,
      confirmationReplies: replies,
    );
    addTearDown(controller.dispose);
    controller.send('合成任务');
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    markCallCardPresented(controller);
    const text = '我不是在问能不能打，我确定现在就打';
    controller.send(text);
    expect(replies.inputs, [text]);
    replies.pending.single.complete(const CallReply(CallReplyDecision.confirm));
    await tester.pump();
    expect(controller.state.preparingCall, isTrue);
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pump();
    expect(ports.commands, hasLength(2));
    expect(ports.commands.last.actionId, 'confirm_call');
    controller.close();
  });
}
