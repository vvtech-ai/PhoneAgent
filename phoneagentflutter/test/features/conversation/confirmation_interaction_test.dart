import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/calls/data/preview_call_flow.dart';
import 'package:phone_agent/features/conversation/domain/confirmation/call_confirmation_policy.dart';
import 'package:phone_agent/features/conversation/domain/confirmation/call_confirmation_reply.dart';
import 'package:phone_agent/features/conversation/domain/confirmation/confirmation_supplement.dart';
import 'package:phone_agent/features/conversation/domain/confirmation/confirmation_supplement_outbox.dart';
import 'package:phone_agent/features/conversation/domain/conversation_messages.dart';
import 'package:phone_agent/features/conversation/domain/history/ledger_event.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_controller.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_state.dart';
import '../../support/confirm_rendered_call.dart';

class _Replies implements CallConfirmationReplyRepository {
  _Replies(this.decision);
  final CallReplyDecision decision;
  @override
  Future<CallReply> classify(CallReplyScope scope, String text) async =>
      CallReply(
        decision,
        decision == CallReplyDecision.question ? '任务尚未拨打。' : '',
      );
}

class _Records
    implements ConfirmationSupplementStore, ConfirmationSupplementRepository {
  List<ConfirmationSupplement> records = [], saved = [];
  @override
  Future<List<ConfirmationSupplement>> read() async => records;
  @override
  Future<void> write(List<ConfirmationSupplement> records) async {
    this.records = records;
  }

  @override
  Future<String> save(String sessionId, ConfirmationSupplement record) async {
    saved.add(record);
    return 'event:${record.id}';
  }
}

void main() {
  testWidgets(
    'duplicate typed/voice confirmation cannot become a new turn during preparation',
    (tester) async {
      final ports = PreviewCallFlow(CallFlowScenario.single);
      final c = ConversationController(
        entry: const ConversationEntry(sessionId: 'mock-call-flow'),
        accountId: 'synthetic',
        gateway: ports,
        history: ports,
        callAdmission: ports.admission,
        callSessions: ports,
      );
      addTearDown(c.dispose);
      c.send('合成需求');
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump();
      confirmRenderedCall(c);
      expect(c.send('确认拨打'), isFalse);
      expect(ports.commands.length, 1);
      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pump();
      expect(ports.commands.length, 2);
      expect(ports.commands.last.actionId, 'confirm_call');
      c.close();
    },
  );
  for (final decision in CallReplyDecision.values) {
    testWidgets(
      'rendered pending task handles $decision through one call owner',
      (tester) async {
        final ports = PreviewCallFlow(CallFlowScenario.single),
            records = _Records();
        late ConversationController c;
        final outbox = ConfirmationSupplementOutbox(
          sessionId: 'mock-call-flow',
          store: records,
          repository: records,
          onRecords: (rows, failed) =>
              c.showConfirmationSupplements(rows, failed),
        );
        c = ConversationController(
          entry: const ConversationEntry(sessionId: 'mock-call-flow'),
          accountId: 'synthetic',
          gateway: ports,
          history: ports,
          callAdmission: ports.admission,
          callSessions: ports,
          confirmationReplies: _Replies(decision),
          supplements: outbox,
        );
        addTearDown(c.dispose);
        c.send('合成需求');
        await tester.pump(const Duration(milliseconds: 1));
        await tester.pump();
        markCallCardPresented(c);
        expect(c.state.phase, ConversationPhase.ready);
        expect(c.calls!.snapshot.launch.request, isNotNull);
        expect(c.calls!.cardPresented, isTrue);
        expect(c.send('按另一种表达处理'), isTrue);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1500));
        await tester.pump();
        if (decision == CallReplyDecision.confirm) {
          expect(ports.commands.length, 2);
          expect(ports.commands.last.actionId, 'confirm_call');
          expect(ports.commands.last.toJson()['actionPayload'], {
            'confirmationText': '按另一种表达处理',
          });
        } else if ({
          CallReplyDecision.edit,
          CallReplyDecision.cancel,
          CallReplyDecision.newRequest,
        }.contains(decision)) {
          expect(ports.commands.length, 2);
          expect(ports.commands.last.message, '按另一种表达处理');
          expect(ports.commands.last.actionId, isNull);
        } else {
          expect(ports.commands.length, 1);
          expect(ports.polls, 0);
          expect(records.saved.length, 1);
          expect(c.state.messages.any((m) => m.text == '按另一种表达处理'), isTrue);
          expect(records.records, isEmpty);
        }
        c.close();
      },
    );
  }
  test(
    'ledger supplements project exactly the same stable local message identities',
    () {
      final messages = ConversationMessages.project([
        LedgerEvent(
          eventId: 'event',
          sessionId: 's',
          sequence: 1,
          type: 'CALL_CONFIRMATION_SUPPLEMENT',
          schemaVersion: 1,
          payload: {
            'recordId': 'r',
            'pendingToolCallId': 't',
            'userText': '问题',
            'assistantText': '回答',
          },
        ),
      ]);
      expect(messages.map((m) => m.id), [
        'confirmation-supplement:r:user',
        'confirmation-supplement:r:assistant',
      ]);
      expect(messages.map((m) => m.text), ['问题', '回答']);
      expect(
        messages.every((m) => m.confirmation == null && m.toolCard == null),
        isTrue,
      );
    },
  );
}
