import 'package:phone_agent/core/design/native_business_dialog.dart';
import '../../support/pump_ui_transitions.dart';
import '../../support/confirm_rendered_call.dart';
import '../../support/confirmation_reply_stub.dart';
import 'package:phone_agent/features/conversation/domain/confirmation/call_confirmation_policy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/calls/data/preview_call_flow.dart';
import 'package:phone_agent/features/calls/presentation/controller/call_session_state.dart';
import 'package:phone_agent/features/calls/presentation/pages/call_flow_preview_page.dart';
import 'package:phone_agent/features/calls/presentation/pages/call_session_page.dart';
import 'package:phone_agent/features/conversation/domain/agent_protocol.dart';
import 'package:phone_agent/features/conversation/domain/conversation_messages.dart';
import 'package:phone_agent/features/conversation/domain/history/conversation_history.dart';
import 'package:phone_agent/features/conversation/domain/history/ledger_event.dart';
import 'package:phone_agent/features/conversation/domain/receipts/call_receipt.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_controller.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_state.dart';

ConversationController conversation(
  PreviewCallFlow ports, {
  void Function()? onTaskResultChanged,
}) {
  var next = 0;
  return ConversationController(
    entry: const ConversationEntry(sessionId: 'mock-call-flow'),
    accountId: 'synthetic',
    gateway: ports,
    history: ports,
    callAdmission: ports.admission,
    callSessions: ports,
    confirmationReplies: const ConfirmationReplyStub(
      decisions: {
        '修改需求，新输入': CallReplyDecision.edit,
        '合成需求': CallReplyDecision.newRequest,
      },
    ),
    onTaskResultChanged: onTaskResultChanged,
    nextId: () => 'id-${next++}',
  );
}

Future<void> launch(
  WidgetTester tester,
  ConversationController controller,
) async {
  controller.send('合成需求');
  await tester.pump(const Duration(milliseconds: 1));
  await tester.pump();
  confirmRenderedCall(controller);
  await tester.pump(const Duration(milliseconds: 1500));
  await tester.pump();
}

void main() {
  for (final failure in [
    AgentTransportFailure.rejected,
    AgentTransportFailure.unavailable,
    AgentTransportFailure.sessionChanged,
  ]) {
    testWidgets('known $failure closes unregistered call without retry', (
      tester,
    ) async {
      final ports = PreviewCallFlow(
        CallFlowScenario.single,
        confirmFailure: failure,
      );
      final c = conversation(ports);
      addTearDown(c.dispose);
      await launch(tester, c);
      expect(c.state.phase, ConversationPhase.recoveryRequired);
      expect(c.calls!.snapshot.showCall, isFalse);
      await tester.pump(const Duration(seconds: 5));
      expect(ports.commands.length, 2);
      expect(ports.polls, 0);
      expect(ports.hangups, 0);
      c.close();
    });
  }
  testWidgets('known error cannot dismiss an already observed call', (
    tester,
  ) async {
    final ports = PreviewCallFlow(CallFlowScenario.single);
    final c = conversation(ports);
    addTearDown(c.dispose);
    await launch(tester, c);
    await tester.pump(const Duration(milliseconds: 1500));
    expect(c.calls!.snapshot.call!.target.callId, 'mock-call');
    c.calls!.confirmationFailed(AgentTransportFailure.rejected);
    expect(c.calls!.snapshot.showCall, isTrue);
    c.close();
  });
  testWidgets(
    'single live request submits voice action without replaying input and opens observer',
    (tester) async {
      final ports = PreviewCallFlow(CallFlowScenario.single);
      final c = conversation(ports);
      addTearDown(c.dispose);
      c.send('合成需求');
      await tester.pump();
      expect(c.calls!.snapshot.showCall, isFalse);
      await tester.pump(const Duration(seconds: 5));
      expect(ports.commands.length, 1);
      expect(c.send('确认拨打'), isFalse);
      confirmRenderedCall(c);
      await tester.pump(const Duration(milliseconds: 1499));
      expect(ports.commands.length, 1);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump();
      expect(ports.commands.length, 2);
      final action = ports.commands.last.toJson();
      expect(action['actionId'], 'confirm_call');
      expect(action['channel'], 'voice');
      expect(action['pendingToolCallId'], 'mock-tool-1');
      expect(action.containsKey('message'), isFalse);
      expect(action['commandId'], action['idempotencyKey']);
      expect(action['commandId'], isNot(ports.commands.first.commandId));
      expect(c.calls!.snapshot.call, isNotNull);
      expect(c.calls!.snapshot.showCall, isFalse);
      await tester.pump(const Duration(milliseconds: 500));
      expect(c.calls!.snapshot.showCall, isTrue);
      expect(c.state.messages.where((m) => m.role.name == 'user').length, 2);
      expect(c.state.messages.where((m) => m.text == '确认拨打'), hasLength(1));
      c.close();
    },
  );
  testWidgets('batch confirms without opening single call page', (
    tester,
  ) async {
    final ports = PreviewCallFlow(CallFlowScenario.batch);
    final c = conversation(ports);
    addTearDown(c.dispose);
    await launch(tester, c);
    expect(ports.commands.last.actionId, 'confirm_call');
    expect(c.calls!.snapshot.showCall, isFalse);
    expect(ports.polls, 0);
    expect(c.state.messages.any((m) => m.batchReceipt != null), isTrue);
  });
  testWidgets('active single call ignores duplicate and replacement tools', (
    tester,
  ) async {
    final ports = PreviewCallFlow(CallFlowScenario.single);
    final c = conversation(ports);
    addTearDown(c.dispose);
    await launch(tester, c);
    final original = c.calls!.activeRequest!;
    for (final tool in [original.toolId, 'replacement-tool']) {
      c.calls!.receive(
        sessionId: original.sessionId,
        commandId: 'later-command',
        toolId: tool,
        spec: {
          'targetName': original.confirmation.targetName,
          'phoneNumber': original.confirmation.phoneNumber,
        },
      );
    }
    await tester.pump(const Duration(seconds: 3));
    expect(ports.commands.length, 2);
    expect(c.calls!.activeRequest, same(original));
    expect(c.calls!.snapshot.showCall, isTrue);
    c.close();
  });
  testWidgets(
    'first insufficient inserts one local message; repeated only decides dialog',
    (tester) async {
      final ports = PreviewCallFlow(CallFlowScenario.insufficient);
      final c = conversation(ports);
      addTearDown(c.dispose);
      await launch(tester, c);
      expect(ports.commands.length, 1);
      expect(ports.noticePosts, 1);
      expect(
        c.state.messages.where((m) => m.text.startsWith('积分不足')).length,
        1,
      );
      await launch(tester, c);
      expect(ports.commands.length, 1);
      expect(ports.noticePosts, 1);
      expect(
        c.calls!.snapshot.launch.decision!.kind.name,
        'repeatedInsufficient',
      );
      expect(c.calls!.snapshot.showCall, isFalse);
      expect(
        c.state.messages.where((m) => m.text.startsWith('积分不足')).length,
        1,
      );
    },
  );
  testWidgets(
    'physical completion releases UI and input while Agent result remains pending',
    (tester) async {
      final ports = PreviewCallFlow(CallFlowScenario.single);
      final c = conversation(ports);
      addTearDown(c.dispose);
      await launch(tester, c);
      ports.ended = true;
      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pump();
      expect(c.calls!.snapshot.call!.phase, CallSessionPhase.awaitingOutcome);
      expect(c.calls!.snapshot.showCall, isFalse);
      expect(c.state.canSend, true);
      expect(c.state.messages.any((m) => m.receipt != null), isTrue);
      ports.outcomeReady = true;
      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pump();
      expect(c.calls!.snapshot.showCall, isFalse);
      expect(
        c.state.messages.any(
          (m) => m.receipt?.metadata['agentOutcome'] == 'SUCCESS',
        ),
        isTrue,
      );
      expect(c.state.activity, isEmpty);
      expect(ports.commands.length, 2);
    },
  );

  testWidgets('late call result refreshes task state once', (tester) async {
    final ports = PreviewCallFlow(CallFlowScenario.single);
    var refreshes = 0;
    final c = conversation(ports, onTaskResultChanged: () => refreshes++);
    addTearDown(c.dispose);
    await launch(tester, c);
    ports.ended = true;
    await tester.pump(const Duration(milliseconds: 1500));
    ports.outcomeReady = true;
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pump();
    expect(
      refreshes,
      1,
      reason: c.state.messages
          .where((message) => message.receipt != null)
          .map(
            (message) =>
                '${message.id}: ${message.receipt!.status}, '
                'call=${message.receipt!.callId}, '
                'attempt=${message.receipt!.attemptId}, '
                'metadata=${message.receipt!.metadata}',
          )
          .join('\n'),
    );
    ports.outcomeReady = true;
    await tester.pump(const Duration(milliseconds: 1500));
    expect(refreshes, 1);
  });
  testWidgets('physical-only receipt with copied outcome keeps observation', (
    tester,
  ) async {
    final ports = PreviewCallFlow(CallFlowScenario.single);
    var refreshes = 0;
    final c = conversation(ports, onTaskResultChanged: () => refreshes++);
    addTearDown(c.dispose);
    await launch(tester, c);
    ports.ended = true;
    await tester.pump(const Duration(milliseconds: 1500));
    c.calls!.acceptReceipts([
      ConversationMessage(
        id: 'copied-physical-outcome',
        role: MessageRole.assistant,
        text: '',
        receipt: CallReceipt(
          attemptId: 'mock-attempt',
          callId: 'mock-call',
          status: 'COMPLETED',
          metadata: {'physicalTerminalOnly': 'true', 'agentOutcome': 'UNCLEAR'},
        ),
      ),
    ]);
    expect(c.calls!.activeRequest, isNotNull);
    ports.outcomeReady = true;
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pump();
    expect(refreshes, 1);
  });
  testWidgets('hangup is explicit once; dismiss alone never hangs up', (
    tester,
  ) async {
    final ports = PreviewCallFlow(CallFlowScenario.single);
    final c = conversation(ports);
    addTearDown(c.dispose);
    await launch(tester, c);
    final first = c.calls!.hangUp();
    final second = c.calls!.hangUp();
    await tester.pump();
    await first;
    await second;
    expect(ports.hangups, 1);
    expect(c.calls!.snapshot.showCall, isFalse);
    c.calls!.dismissCall();
    expect(ports.hangups, 1);
  });
  testWidgets(
    'network uncertainty retains observation and restore never reposts confirm',
    (tester) async {
      final ports = PreviewCallFlow(CallFlowScenario.uncertain);
      final c = conversation(ports);
      addTearDown(c.dispose);
      await launch(tester, c);
      expect(c.state.phase, ConversationPhase.recoveryRequired);
      expect(c.calls!.snapshot.call, isNotNull);
      expect(c.calls!.snapshot.showCall, isFalse);
      c.calls!.dismissCall();
      await c.restore();
      await tester.pump(const Duration(seconds: 5));
      expect(ports.commands.length, 2);
      expect(ports.hangups, 0);
    },
  );
  testWidgets(
    'close during delay cancels confirm; history never launches its pending request',
    (tester) async {
      final ports = _HistoryCallFlow();
      final c = conversation(ports);
      addTearDown(c.dispose);
      await c.restore();
      await tester.pump(const Duration(seconds: 2));
      expect(c.state.messages.any((m) => m.confirmation != null), isTrue);
      expect(ports.commands, isEmpty);
      markCallCardPresented(c);
      c.send('修改需求，新输入');
      await tester.pump();
      c.close();
      await tester.pump(const Duration(seconds: 2));
      expect(ports.commands.length, 1);
      expect(ports.hangups, 0);
    },
  );
  testWidgets(
    'shared page requires rendered confirmation and blocks back during call',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: CallFlowPreviewPage(scenario: CallFlowScenario.single),
        ),
      );
      await tester.tap(find.text('发送合成需求'));
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump();
      expect(find.byType(CallSessionPage), findsNothing);
      await tester.tap(find.text('确认合成拨打'));
      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(CallSessionPage), findsOneWidget);
      expect(find.text('演练门店'), findsWidgets);
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.byType(CallSessionPage), findsOneWidget);
      expect(find.byType(CallFlowPreviewPage), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'repeated insufficiency dialog dismisses to original conversation',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: CallFlowPreviewPage(scenario: CallFlowScenario.insufficient),
        ),
      );
      for (var i = 0; i < 2; i++) {
        if (i == 0) await tester.tap(find.text('发送合成需求'));
        await tester.pump(const Duration(milliseconds: 1));
        await tester.pump();
        await tester.tap(find.text('确认合成拨打'));
        await tester.pump(const Duration(milliseconds: 1500));
        await tester.pump();
      }
      await tester.pumpUntilUiSettled();
      expect(find.byType(NativeBusinessDialog), findsOneWidget);
      await tester.tap(find.text('知道了'));
      await tester.pumpUntilUiSettled();
      expect(find.byType(NativeBusinessDialog), findsNothing);
      expect(find.text('发送合成需求'), findsOneWidget);
      await tester.tap(find.text('确认合成拨打'));
      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pumpUntilUiSettled();
      expect(find.byType(NativeBusinessDialog), findsOneWidget);
      await tester.tap(find.text('知道了'));
      await tester.pumpUntilUiSettled();
      await tester.pumpWidget(const SizedBox());
    },
  );
}

class _HistoryCallFlow extends PreviewCallFlow {
  _HistoryCallFlow() : super(CallFlowScenario.single);
  @override
  Future<RestoredConversation> restore(String sessionId) async =>
      RestoredConversation(
        ConversationDetail(
          sessionId: sessionId,
          title: '合成历史',
          status: 'ACTIVE',
        ),
        ledger: LedgerSnapshot(
          sessionId,
          1,
          const LedgerProjection(
            status: 'ACTIVE',
            continuable: true,
            pendingRestorable: true,
            migrationStatus: 'NATIVE',
            projectedThrough: 1,
          ),
          [
            LedgerEvent(
              eventId: 'history-tool',
              sessionId: sessionId,
              sequence: 1,
              type: 'TOOL_REQUESTED',
              schemaVersion: 1,
              commandId: 'old',
              payload: {
                'toolCallId': 'history-call',
                'toolName': 'makeCall',
                'arguments': {
                  'targetName': '合成历史联系人',
                  'phoneNumber': '+12025550101',
                },
              },
            ),
          ],
        ),
      );
}
