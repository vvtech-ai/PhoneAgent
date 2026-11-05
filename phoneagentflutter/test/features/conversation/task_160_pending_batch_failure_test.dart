import 'dart:async';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/agent_protocol.dart';
import 'package:phone_agent/features/conversation/domain/history/conversation_history.dart';
import 'package:phone_agent/features/conversation/domain/history/ledger_event.dart';
import 'package:phone_agent/features/conversation/domain/receipts/batch_progress_tracker.dart';
import 'package:phone_agent/features/conversation/domain/receipts/batch_receipt.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_controller.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_state.dart';
import 'batch_progress_tracker_test.dart' show progress;

class _Gateway implements AgentGateway {
  final events = StreamController<AgentEvent>.broadcast();
  int starts = 0;
  String commandId = '';
  @override
  AgentRun start(AgentCommand command) {
    starts++;
    commandId = command.commandId;
    return AgentRun(events.stream, () {});
  }
}

class _History implements ConversationHistoryRepository {
  LedgerSnapshot? ledger;
  int reads = 0;
  @override
  Future<RestoredConversation> restore(String sessionId) async =>
      RestoredConversation(
        ConversationDetail(
          sessionId: sessionId,
          title: '${++reads}',
          status: 'RUNNING',
        ),
        ledger: ledger,
      );
}

void main() {
  test(
    'failure before batch identity uses session reads and only a matching final releases the gate',
    () {
      fakeAsync((clock) {
        final gateway = _Gateway(), history = _History();
        final controller = ConversationController(
          entry: const ConversationEntry(sessionId: 'session'),
          accountId: 'synthetic',
          gateway: gateway,
          history: history,
        );
        controller.send('合成批次');
        gateway.events.add(
          const AgentEvent(
            AgentEventKind.toolStart,
            payload: {'name': 'makeBatchCalls'},
          ),
        );
        gateway.events.addError(AgentTransportFailure.network);
        clock.flushMicrotasks();
        expect(history.reads, greaterThan(0));
        expect(controller.send('不得重拨'), isFalse);
        final fact = LedgerEvent(
          eventId: 'final',
          sessionId: 'session',
          sequence: 1,
          commandId: gateway.commandId,
          type: 'ASSISTANT_TURN_COMMITTED',
          schemaVersion: 1,
          payload: {
            'text': '批次已确认',
            'batchCallResult': {
              'batchId': 'verified-batch',
              'status': 'COMPLETED',
              'items': [
                {'status': 'SUCCESS'},
              ],
            },
          },
        );
        history.ledger = LedgerSnapshot(
          'session',
          1,
          const LedgerProjection(
            status: 'ACTIVE',
            continuable: true,
            pendingRestorable: false,
            migrationStatus: 'NATIVE',
            projectedThrough: 1,
          ),
          [fact],
        );
        clock.elapse(const Duration(seconds: 5));
        clock.flushMicrotasks();
        expect(
          controller.state.messages.any(
            (m) => m.batchReceipt?.explicitId == 'verified-batch',
          ),
          isTrue,
        );
        expect(controller.send('确认后允许新请求'), isTrue);
        expect(gateway.starts, 2);
        controller.dispose();
        gateway.events.close();
        clock.flushMicrotasks();
        expect(clock.nonPeriodicTimerCount, 0);
      });
    },
  );
  test(
    'verifying is provisional and is excluded from completed route count',
    () {
      final receipt = BatchReceipt.fromJson({
        'status': 'RUNNING',
        'items': [
          {'status': 'SUCCESS'},
          {'status': 'VERIFYING'},
        ],
      }, fallbackId: 'batch');
      expect(receipt.completedCount, 1);
      expect(receipt.items.last.outcome, BatchItemOutcome.running);
    },
  );
  test('physical stop and result pending use the current native copy', () {
    expect(BatchProgressTracker.headline('STOP_ACCEPTED'), '正在确认通话状态');
    expect(
      BatchProgressTracker.headline('PRIMARY_CLOSED_FORK_OBSERVING'),
      '正在确认通话状态',
    );
    expect(BatchProgressTracker.headline('RESULT_PENDING'), '正在整理通话结果');
  });
  for (final eventError in [false, true]) {
    test(
      'active batch failure event=$eventError preserves identity and never fabricates final failure',
      () async {
        final gateway = _Gateway();
        final controller = ConversationController(
          entry: const ConversationEntry(sessionId: 'session'),
          accountId: 'synthetic',
          gateway: gateway,
          history: _History(),
        );
        addTearDown(() {
          controller.dispose();
          gateway.events.close();
        });
        controller.send('邀请两位联系人');
        gateway.events.add(progress(1, 'SUCCESS'));
        gateway.events.add(progress(2, 'CALLING'));
        await Future<void>.delayed(Duration.zero);
        if (eventError) {
          gateway.events.add(
            const AgentEvent(AgentEventKind.error, text: 'synthetic failure'),
          );
        } else {
          gateway.events.addError(AgentTransportFailure.network);
        }
        await Future<void>.delayed(Duration.zero);
        final receipt = controller.state.messages
            .where((m) => m.batchReceipt != null)
            .single
            .batchReceipt!;
        expect(receipt.status, 'RUNNING');
        expect(receipt.items.map((i) => i.status), ['SUCCESS', 'VERIFYING']);
        expect(receipt.completedCount, 1);
        expect(controller.state.activity, contains('核对拨号状态'));
        expect(controller.state.phase, ConversationPhase.ready);
        expect(controller.send('不得重新拨打'), isFalse);
        expect(gateway.starts, 1);
      },
    );
  }

}
