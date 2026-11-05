import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/agent_protocol.dart';
import 'package:phone_agent/features/conversation/domain/receipts/batch_receipt.dart';
import 'package:phone_agent/features/conversation/domain/receipts/batch_progress_tracker.dart';

AgentEvent progress(
  int index,
  String status, {
  String batch = 'batch',
  int total = 3,
  String text = '合成状态',
  String name = '',
}) => AgentEvent(
  AgentEventKind.status,
  text: text,
  payload: {
    'batchId': batch,
    'itemIndex': index,
    'status': status,
    'total': total,
    'targetName': name,
  },
);

void main() {
  test(
    'result marker without an identified receipt cannot finalize a batch',
    () {
      for (final payload in <Map<String, Object?>>[
        {'type': 'BATCH_CALL_RESULT'},
        {'type': 'BATCH_CALL_RESULT', 'batchCallResult': <String, Object?>{}},
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
        expect(
          BatchProgressTracker.isFinal(
            AgentEvent(AgentEventKind.finalResponse, payload: payload),
          ),
          isFalse,
        );
      }
    },
  );

  test('tool start marks active and blank factual progress updates routes', () {
    final tracker = BatchProgressTracker();
    expect(
      tracker.accept(
        const AgentEvent(
          AgentEventKind.toolStart,
          payload: {'name': 'makeBatchCalls'},
        ),
        'c',
      ),
      isTrue,
    );
    expect(tracker.active, isTrue);
    expect(tracker.snapshot(), isNull);
    expect(tracker.accept(progress(1, 'CALLING', text: ''), 'c'), isTrue);
    expect(
      tracker.accept(
        const AgentEvent(AgentEventKind.status, text: '普通单路'),
        'c',
      ),
      isFalse,
    );
  });
  test('queued routes remain visible as waiting call items', () {
    final tracker = BatchProgressTracker();
    tracker.accept(
      const AgentEvent(
        AgentEventKind.toolStart,
        payload: {'name': 'makeBatchCalls'},
      ),
      'c',
    );

    expect(
      tracker.accept(
        progress(3, 'WAITING_CALL', text: 'Carol 等待呼叫中，当前最多同时呼叫 2 路'),
        'c',
      ),
      isTrue,
    );
    final item = tracker.snapshot()!.items.single;
    expect(item.outcome, BatchItemOutcome.running);
    expect(item.headline, '等待呼叫中');
    expect(item.detail, contains('等待呼叫中'));
    expect(tracker.snapshot()!.completedCount, 0);
  });
  test('rejected retry admission does not count as a second physical call', () {
    final tracker = BatchProgressTracker();
    AgentEvent route(
      String status,
      String phase,
      String attempt,
      int number, {
      String evidence = '',
      String message = '',
    }) => AgentEvent(
      AgentEventKind.status,
      payload: {
        'batchId': 'batch',
        'itemIndex': 1,
        'total': 2,
        'status': status,
        'phase': phase,
        'callAttemptId': attempt,
        'attemptNumber': number,
        'evidenceLevel': evidence,
        'message': message,
      },
    );
    tracker.accept(route('CALLING', 'CALLING', 'first', 1), 'c');
    tracker.accept(
      route('RECALLING', 'CALLING', 'retry', 2, message: '正在自动重拨'),
      'c',
    );
    expect(tracker.snapshot()!.items.single.recalled, isTrue);
    tracker.accept(
      route(
        'FAILED',
        'FAILED',
        'retry',
        2,
        evidence: 'ADMISSION',
        message: '重拨未发起：积分不足',
      ),
      'c',
    );

    final item = tracker.snapshot()!.items.single;
    expect(item.status, 'FAILED');
    expect(item.attemptCount, 1);
    expect(item.recalled, isFalse);
    expect(item.detail, contains('重拨未发起'));
  });
  test(
    'late admission snapshot cannot replace versioned physical progress',
    () {
      final tracker = BatchProgressTracker();
      AgentEvent fact(
        String status,
        String phase,
        int version,
        String evidence,
      ) => AgentEvent(
        AgentEventKind.status,
        payload: {
          'batchId': 'batch',
          'itemIndex': 1,
          'total': 1,
          'status': status,
          'phase': phase,
          'phaseVersion': version,
          'evidenceLevel': evidence,
          'callAttemptId': 'attempt',
          'attemptNumber': 1,
        },
      );
      expect(
        tracker.accept(fact('RINGING', 'RINGING', 100, 'SDK_STATUS'), 'c'),
        isTrue,
      );
      expect(
        tracker.accept(fact('VERIFYING', 'VERIFYING', 0, 'ADMISSION'), 'c'),
        isFalse,
      );
      expect(tracker.snapshot()!.items.single.headline, '正在振铃，等待接听');
    },
  );
  test(
    'physical evidence restores each route phase after stream uncertainty',
    () {
      for (final (evidence, phase, headline) in <(String, String, String)>[
        ('SDK_STATUS', 'CONNECTED', '正在通话'),
        ('PRIMARY_CLOSED', 'PRIMARY_CLOSED_FORK_OBSERVING', '正在确认通话状态'),
        ('STOP_ACCEPTED', 'STOP_ACCEPTED', '正在确认通话状态'),
        ('PHYSICAL_TERMINAL', 'RESULT_PENDING', '正在整理通话结果'),
      ]) {
        final tracker = BatchProgressTracker();
        AgentEvent fact(String stage, String proof, int version) => AgentEvent(
          AgentEventKind.status,
          payload: {
            'batchId': 'batch',
            'itemIndex': 1,
            'total': 2,
            'status': 'RUNNING',
            'phase': stage,
            'phaseVersion': version,
            'callAttemptId': 'attempt-1',
            'attemptNumber': 1,
            'evidenceLevel': proof,
          },
        );
        tracker.accept(fact('CALLING', 'SDK_STATUS', 1), 'command');
        tracker.markUncertain();
        expect(tracker.snapshot()!.items.single.status, 'VERIFYING');

        expect(tracker.accept(fact(phase, evidence, 2), 'command'), isTrue);
        final route = tracker.snapshot()!.items.single;
        expect(route.status, 'CALLING', reason: evidence);
        expect(route.headline, headline, reason: evidence);
        expect(tracker.snapshot()!.completedCount, 0, reason: evidence);
      }
    },
  );
  test(
    'weak or unbound proof stays uncertain until a route result arrives',
    () {
      for (final (evidence, attempt) in <(String, String)>[
        ('ADMISSION', 'attempt-1'),
        ('', 'attempt-1'),
        ('SDK_STATUS', ''),
      ]) {
        final tracker = BatchProgressTracker();
        AgentEvent fact(
          String status,
          String phase,
          int version,
          String callAttemptId,
        ) => AgentEvent(
          AgentEventKind.status,
          payload: {
            'batchId': 'batch',
            'itemIndex': 1,
            'total': 1,
            'status': status,
            'phase': phase,
            'phaseVersion': version,
            'callAttemptId': callAttemptId,
            'attemptNumber': 1,
            'evidenceLevel': evidence,
          },
        );
        tracker.accept(fact('RUNNING', 'CALLING', 1, 'attempt-1'), 'command');
        tracker.markUncertain();
        tracker.accept(fact('RUNNING', 'CALLING', 2, attempt), 'command');
        final route = tracker.snapshot()!.items.single;
        expect(route.status, 'VERIFYING', reason: '$evidence / $attempt');
        expect(route.headline, '正在核对拨号状态');
        expect(tracker.snapshot()!.completedCount, 0);

        tracker.accept(fact('SUCCESS', '', 3, 'attempt-1'), 'command');
        expect(tracker.snapshot()!.items.single.status, 'SUCCESS');
        expect(tracker.snapshot()!.completedCount, 1);
      }
    },
  );
  test(
    'fresh progress read clears stale error without resolving unknown routes',
    () {
      final tracker = BatchProgressTracker();
      AgentEvent fact(int index, String phase, String evidence, int version) =>
          AgentEvent(
            AgentEventKind.status,
            payload: {
              'batchId': 'batch',
              'itemIndex': index,
              'total': 2,
              'status': 'RUNNING',
              'phase': phase,
              'phaseVersion': version,
              'callAttemptId': 'attempt-$index',
              'attemptNumber': 1,
              'evidenceLevel': evidence,
            },
          );
      tracker.accept(fact(1, 'CALLING', 'SDK_STATUS', 1), 'command');
      tracker.accept(fact(2, 'CALLING', 'ADMISSION', 1), 'command');
      tracker.markUncertain();
      expect(tracker.snapshot()!.headline, contains('外呼请求失败'));
      expect(tracker.snapshot()!.items.last.status, 'VERIFYING');

      tracker.accept(fact(1, 'CONNECTED', 'SDK_STATUS', 2), 'command');
      tracker.progressRead();
      final refreshed = tracker.snapshot()!;
      expect(refreshed.headline, isNot(contains('外呼请求失败')));
      expect(refreshed.items.first.headline, '正在通话');
      expect(refreshed.items.last.status, 'VERIFYING');

      tracker.accept(fact(2, 'CALLING', 'ADMISSION', 2), 'command');
      expect(tracker.snapshot()!.items.last.status, 'VERIFYING');
      expect(tracker.uncertain, isTrue);
    },
  );
  test(
    'physical phases, versions and recall attempts do not become results',
    () {
      final tracker = BatchProgressTracker();
      AgentEvent fact(
        String phase,
        int version, {
        String attempt = 'a',
        int number = 1,
        String status = 'FAILED',
      }) => AgentEvent(
        AgentEventKind.status,
        payload: {
          'batchId': 'b',
          'itemIndex': 1,
          'total': 4,
          'phase': phase,
          'phaseVersion': version,
          'callAttemptId': attempt,
          'attemptNumber': number,
          'status': status,
        },
      );
      expect(tracker.accept(fact('CALLING', 1), 'c'), isTrue);
      expect(tracker.snapshot()!.completedCount, 0);
      expect(tracker.snapshot()!.items.single.headline, '正在拨打');
      tracker.accept(fact('RESULT_PENDING', 3), 'c');
      expect(tracker.snapshot()!.completedCount, 0);
      expect(tracker.accept(fact('RINGING', 2), 'c'), isFalse);
      tracker.accept(fact('', 4, status: 'SUCCESS'), 'c');
      expect(tracker.snapshot()!.completedCount, 1);
      expect(tracker.accept(fact('CONNECTED', 5), 'c'), isFalse);
      expect(
        tracker.accept(fact('CALLING', 1, attempt: 'b', number: 2), 'c'),
        isTrue,
      );
      expect(tracker.accept(fact('', 9, status: 'FAILED'), 'c'), isFalse);
      expect(tracker.snapshot()!.completedCount, 0);
    },
  );
  test(
    'only complete route evidence holds finalization without another stop',
    () {
      final tracker = BatchProgressTracker();
      AgentEvent fact(String phase, String status) => AgentEvent(
        AgentEventKind.status,
        payload: {
          'batchId': 'b',
          'total': 1,
          'itemIndex': 1,
          'phase': phase,
          'status': status,
          'callAttemptId': 'attempt',
        },
      );
      tracker.accept(fact('PHYSICAL_CLOSED', 'FAILED'), 'c');
      expect(tracker.awaitingAggregate, isFalse);
      tracker.accept(fact('', 'SUCCESS'), 'c');
      expect(tracker.awaitingAggregate, isTrue);
      expect(
        tracker.active,
        isTrue,
        reason: 'route proof is not the aggregate receipt',
      );
      tracker.finish('c');
      expect(tracker.awaitingAggregate, isFalse);
    },
  );
  test(
    'out of order indices remain ordered, repeated item updates and total never shrinks',
    () {
      final tracker = BatchProgressTracker();
      tracker.accept(progress(3, 'CALLING'), 'c');
      tracker.accept(progress(1, 'CALLING', name: '甲'), 'c');
      tracker.accept(progress(1, 'CONFIRMED', total: 1), 'c');
      final snapshot = tracker.snapshot()!;
      expect(snapshot.items.map((i) => i.id), [
        'progress_batch_1',
        'progress_batch_3',
      ]);
      expect(snapshot.items.first.targetName, '甲');
      expect(snapshot.items.first.status, 'SUCCESS');
      expect(snapshot.totalCount, 3);
      expect(snapshot.completedCount, 1);
      expect(snapshot.status, 'RUNNING');
    },
  );
  test('pending identity binds real batch and recall remains two attempts', () {
    final tracker = BatchProgressTracker();
    tracker.accept(progress(1, 'CALLING', batch: ''), 'c');
    tracker.accept(progress(2, 'RETRYING', text: '重拨'), 'c');
    tracker.accept(progress(2, 'SUCCESS'), 'c');
    expect(tracker.snapshot()!.items, hasLength(2));
    expect(tracker.snapshot()!.items.last.attemptCount, 2);
    expect(tracker.snapshot()!.items.last.recalled, isTrue);
    expect(tracker.snapshot()!.explicitId, 'batch');
  });
  test(
    'different command or real batch resets progress rather than mixing routes',
    () {
      final tracker = BatchProgressTracker();
      tracker.accept(progress(1, 'SUCCESS'), 'a');
      tracker.accept(progress(2, 'CALLING', batch: 'other'), 'a');
      expect(tracker.snapshot()!.items, hasLength(1));
      tracker.accept(progress(1, 'FAILED', total: 1), 'b');
      expect(tracker.snapshot()!.totalCount, 1);
      expect(tracker.snapshot()!.items.single.status, 'FAILED');
    },
  );
  test(
    'failure preserves terminal items and marks only running routes incomplete',
    () {
      final tracker = BatchProgressTracker();
      tracker.accept(progress(1, 'SUCCESS'), 'c');
      tracker.accept(progress(2, 'RECALLING'), 'c');
      final failed = tracker.snapshot(failed: true)!;
      expect(failed.status, 'FAILED');
      expect(failed.items.first.status, 'SUCCESS');
      expect(failed.items.last.headline, '结果未完整返回');
      expect(failed.items.last.billing, isEmpty);
      expect(tracker.snapshot()!.items.last.status, 'RECALLING');
    },
  );
  test('finish prevents late status from reviving a terminal command', () {
    final tracker = BatchProgressTracker();
    tracker.accept(progress(1, 'CALLING'), 'c');
    tracker.finish('c');
    expect(tracker.accept(progress(1, 'CALLING'), 'c'), isFalse);
    expect(tracker.active, isFalse);
    expect(tracker.accept(progress(1, 'CALLING'), 'next'), isFalse);
    expect(
      tracker.accept(progress(1, 'CALLING', batch: 'new'), 'next'),
      isTrue,
    );
  });
  test(
    'status normalization follows v65 rather than treating unknown as success',
    () {
      for (final value in ['REJECTED', 'TIMEOUT', 'HUNG_UP']) {
        expect(BatchProgressTracker.normalize(value), 'FAILED');
      }
      expect(BatchProgressTracker.normalize('PENDING'), 'UNCLEAR');
      expect(BatchProgressTracker.normalize('needs_recall'), 'NEEDS_RECALL');
      expect(BatchProgressTracker.normalize('future'), 'FUTURE');
    },
  );
  test('provisional unclear statuses never use the completed headline', () {
    for (final status in ['UNCLEAR', 'PENDING', 'ABNORMAL', '', 'FUTURE']) {
      expect(
        BatchProgressTracker.headline(status),
        status == 'FUTURE' ? '结果待确认' : '结果确认中',
      );
      expect(BatchProgressTracker.headline(status), isNot('任务完成'));
    }
  });
}
