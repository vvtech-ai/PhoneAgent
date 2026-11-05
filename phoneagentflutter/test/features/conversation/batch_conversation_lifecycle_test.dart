import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/agent_protocol.dart';
import 'package:phone_agent/features/conversation/domain/history/conversation_history.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_controller.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_state.dart';
import 'package:phone_agent/features/conversation/presentation/controller/detached_batch_streams.dart';
import 'batch_progress_tracker_test.dart' show progress;

void main() {
  late _Gateway gateway;
  late _History history;
  late DetachedBatchStreams detached;
  late ConversationController controller;
  var refreshReads = <int>[];
  int id = 0;
  Future<void> flush() => Future<void>.delayed(Duration.zero);
  setUp(() {
    gateway = _Gateway();
    history = _History();
    refreshReads = [];
    detached = DetachedBatchStreams(
      onFinished: () {
        refreshReads.add(history.reads);
      },
    );
    controller = ConversationController(
      entry: const ConversationEntry(sessionId: 's'),
      accountId: 'synthetic',
      gateway: gateway,
      history: history,
      detachedBatches: detached,
      nextId: () => 'id${id++}',
    );
    controller.send('合成批量需求');
  });
  tearDown(() {
    controller.dispose();
    detached.close();
  });
  test(
    'progress updates shared receipt without entering single-call page',
    () async {
      gateway.events.add(progress(2, 'CALLING'));
      gateway.events.add(progress(1, 'SUCCESS'));
      await flush();
      final batch = controller.state.messages
          .where((m) => m.batchReceipt != null)
          .single
          .batchReceipt!;
      expect(batch.items.map((i) => i.status), ['SUCCESS', 'CALLING']);
      expect(controller.state.phase, ConversationPhase.sending);
      expect(controller.send('重复新轮'), isFalse);
      expect(controller.calls, isNull);
    },
  );
  test(
    'final replaces provisional card and late progress cannot revive it',
    () async {
      gateway.events.add(progress(1, 'CALLING'));
      gateway.events.add(
        const AgentEvent(
          AgentEventKind.finalResponse,
          payload: {
            'type': 'BATCH_CALL_RESULT',
            'batchCallResult': {
              'batchId': 'batch',
              'status': 'COMPLETED',
              'items': [
                {
                  'itemId': 'authoritative',
                  'status': 'SUCCESS',
                  'callId': 'recording-anchor',
                },
              ],
            },
          },
        ),
      );
      gateway.events.add(progress(1, 'CALLING'));
      gateway.events.add(const AgentEvent(AgentEventKind.done));
      await flush();
      final results = controller.state.messages.where(
        (m) => m.batchReceipt != null,
      );
      expect(results, hasLength(1));
      expect(results.single.batchReceipt!.items.single.id, 'authoritative');
      expect(
        results.single.batchReceipt!.items.single.callId,
        'recording-anchor',
      );
      expect(controller.state.canSend, isTrue);
      expect(history.reads, 0);
    },
  );
  test(
    'execution error ends waiting while preserving an unresolved route',
    () async {
      gateway.events.add(progress(1, 'FAILED'));
      gateway.events.add(progress(2, 'CALLING'));
      await flush();
      Map<String, Object?> result(String secondStatus) => {
        'type': 'BATCH_CALL_RESULT',
        'batchCallResult': {
          'batchId': 'batch',
          'status': 'RUNNING',
          'executionStatus': 'EXECUTION_ERROR',
          'headline': '本次任务已结束，结果处理异常',
          'items': [
            {'itemId': 'first', 'status': 'FAILED'},
            {'itemId': 'second', 'status': secondStatus},
          ],
        },
      };
      gateway.events.add(
        AgentEvent(AgentEventKind.finalResponse, payload: result('CALLING')),
      );
      await flush();
      expect(
        controller.state.messages
            .where((message) => message.batchReceipt != null)
            .single
            .batchReceipt!
            .isRunning,
        isFalse,
      );
      gateway.events.add(const AgentEvent(AgentEventKind.done));
      await flush();
      expect(controller.state.phase, ConversationPhase.ready);
      expect(controller.state.canSend, isTrue);
      final batch = controller.state.messages
          .where((message) => message.batchReceipt != null)
          .single
          .batchReceipt!;
      expect(batch.isRunning, isFalse);
      expect(batch.completedCount, 1);
      expect(batch.items.last.status, 'CALLING');
      expect(batch.successCount, 0);
    },
  );
  test(
    'empty execution error closes the current batch without inventing routes',
    () async {
      gateway.events.add(progress(1, 'CALLING'));
      await flush();
      gateway.events.add(
        const AgentEvent(
          AgentEventKind.finalResponse,
          text: '本次任务已结束，结果处理异常',
          payload: {
            'type': 'BATCH_CALL_RESULT',
            'batchCallResult': {
              'status': 'PENDING',
              'executionStatus': 'EXECUTION_ERROR',
              'headline': '执行异常',
              'items': <Object>[],
            },
          },
        ),
      );
      gateway.events.add(const AgentEvent(AgentEventKind.done));
      await flush();

      expect(controller.state.phase, ConversationPhase.ready);
      expect(controller.state.canSend, isTrue);
      final cards = controller.state.messages.where(
        (message) => message.batchReceipt != null,
      );
      expect(cards, hasLength(1));
      final batch = cards.single.batchReceipt!;
      expect(batch.executionStatus, 'EXECUTION_ERROR');
      expect(batch.isRunning, isFalse);
      expect(batch.items, isEmpty);
      expect(batch.explicitId, isEmpty);
      expect(batch.detail, '本次任务已结束，结果处理异常');
    },
  );
  test('malformed batch result cannot erase active progress', () async {
    gateway.events.add(progress(1, 'CALLING'));
    await flush();
    for (final payload in <Map<String, Object?>>[
      {'type': 'BATCH_CALL_RESULT'},
      {
        'type': 'BATCH_CALL_RESULT',
        'batchCallResult': {
          'status': 'FAILED',
          'items': [
            {'itemId': 'first', 'status': 'FAILED'},
          ],
        },
      },
    ]) {
      gateway.events.add(
        AgentEvent(AgentEventKind.finalResponse, payload: payload),
      );
      await flush();
      final cards = controller.state.messages.where(
        (message) => message.batchReceipt != null,
      );
      expect(cards, hasLength(1));
      expect(cards.single.batchReceipt!.explicitId, 'batch');
      expect(cards.single.batchReceipt!.isRunning, isTrue);
    }
  });
  test(
    'exit preserves active transport but never updates old or new page',
    () async {
      gateway.events.add(progress(1, 'CALLING'));
      await flush();
      controller.close();
      expect(gateway.cancels, 0);
      expect(detached.hasActive, isTrue);
      final otherGateway = _Gateway();
      final other = ConversationController(
        entry: const ConversationEntry(sessionId: 'other'),
        accountId: 'synthetic',
        gateway: otherGateway,
        history: history,
        detachedBatches: detached,
      );
      expect(other.send('暂不新发'), isFalse);
      gateway.events.add(
        const AgentEvent(
          AgentEventKind.signal,
          text: '不得污染',
          payload: {'type': 'ASK_USER'},
        ),
      );
      gateway.events.add(const AgentEvent(AgentEventKind.done));
      await flush();
      expect(controller.state.messages, isEmpty);
      expect(other.state.messages, isEmpty);
      expect(detached.hasActive, isFalse);
      expect(gateway.cancels, 1);
      expect(other.send('结束后新轮'), isTrue);
      other.dispose();
    },
  );
  test(
    'Done without final performs read-only sync, not fabricated success or POST retry',
    () async {
      gateway.events.add(progress(1, 'CALLING'));
      gateway.events.add(const AgentEvent(AgentEventKind.done));
      await flush();
      expect(history.reads, 1);
      expect(gateway.starts, 1);
      expect(controller.state.messages.last.batchReceipt!.status, 'RUNNING');
      expect(controller.state.notice, contains('确认最新结果'));
      expect(refreshReads, [1]);
    },
  );
  test(
    'stream failure preserves completed routes and verifies missing results',
    () async {
      gateway.events.add(progress(1, 'SUCCESS'));
      gateway.events.add(progress(2, 'CALLING'));
      await flush();
      gateway.events.addError(AgentTransportFailure.network);
      await flush();
      final batch = controller.state.messages.last.batchReceipt!;
      expect(batch.items.first.status, 'SUCCESS');
      expect(batch.items.last.status, 'VERIFYING');
      expect(batch.items.last.headline, '正在核对拨号状态');
      expect(controller.state.phase, ConversationPhase.ready);
      expect(controller.send('不能重复拨号'), isFalse);
      expect(gateway.starts, 1);
    },
  );
  test('ordinary exit still cancels immediately', () async {
    controller.close();
    expect(gateway.cancels, 1);
    expect(detached.count, 0);
  });
}

class _Gateway implements AgentGateway {
  final events = StreamController<AgentEvent>();
  int cancels = 0, starts = 0;
  @override
  AgentRun start(AgentCommand command) {
    starts++;
    return AgentRun(events.stream, () => cancels++);
  }
}

class _History implements ConversationHistoryRepository {
  int reads = 0;
  @override
  Future<RestoredConversation> restore(String sessionId) async {
    reads++;
    return RestoredConversation(
      ConversationDetail(sessionId: sessionId, title: '', status: 'RUNNING'),
    );
  }
}
