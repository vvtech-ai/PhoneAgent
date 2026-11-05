import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/stopping/conversation_stop.dart';
import 'package:phone_agent/features/conversation/domain/stopping/conversation_stop_coordinator.dart';

class _Stops implements ConversationStopRepository {
  final turn = Completer<TurnStopResult>();
  int turns = 0, batches = 0, failures = 1;
  @override
  Future<TurnStopResult> stop(String sessionId, String commandId) {
    turns++;
    return turn.future;
  }

  @override
  Future<BatchStopResult> stopBatch(String sessionId, String batchId) async {
    batches++;
    return BatchStopResult(
      batchId: batchId,
      status: 'STOPPING',
      matchedCalls: 2,
      failedCalls: failures,
    );
  }
}

void main() {
  for (final status in [TurnStopStatus.stopping, TurnStopStatus.notActive]) {
    test('accepted $status stop is silent and still synchronizes', () async {
      final repository = _Stops();
      final notices = <String>[];
      var accepted = 0, reads = 0;
      final c = ConversationStopCoordinator(
        repository: repository,
        sessionId: 's',
        current: () => true,
        accepted: () => accepted++,
        synchronize: () async {
          reads++;
          return true;
        },
        notice: notices.add,
        changed: () {},
      );
      repository.turn.complete(TurnStopResult(status));
      await c.stop('command', (_) async => true);
      expect(accepted, 1);
      expect(reads, 1);
      expect(notices, isEmpty);
    });
  }
  test(
    'stop coalesces, waits for ledger and ignores a superseding command',
    () async {
      final repository = _Stops();
      var accepted = 0, reads = 0;
      final notices = <String>[];
      final c = ConversationStopCoordinator(
        repository: repository,
        sessionId: 's',
        current: () => true,
        accepted: () => accepted++,
        synchronize: () async {
          reads++;
          return true;
        },
        notice: notices.add,
        changed: () {},
      );
      final first = c.stop('command', (_) async => true);
      await c.stop('command', (_) async => true);
      expect(repository.turns, 1);
      c.invalidate();
      repository.turn.complete(const TurnStopResult(TurnStopStatus.stopping));
      await first;
      expect(accepted, 0);
      expect(reads, 0);
      expect(notices, isEmpty);
    },
  );
  test(
    'batch cancel has no hangup; partial stop retries explicitly with the same batch',
    () async {
      final repository = _Stops();
      var accepted = 0;
      final notices = <String>[];
      final c = ConversationStopCoordinator(
        repository: repository,
        sessionId: 's',
        current: () => true,
        accepted: () => accepted++,
        synchronize: () async => true,
        notice: notices.add,
        changed: () {},
      );
      repository.turn.complete(
        const TurnStopResult(TurnStopStatus.batchConfirmationRequired, 'batch'),
      );
      await c.stop('command', (_) async => false);
      expect(repository.batches, 0);
      expect(accepted, 0);
      await c.stop('command', (_) async => true);
      expect(c.retryBatchId, 'batch');
      expect(notices.last, contains('1项'));
      notices.clear();
      repository.failures = 0;
      await c.stop('command', (_) async => true);
      expect(repository.turns, 2);
      expect(repository.batches, 2);
      expect(c.retryBatchId, isNull);
      expect(accepted, 2);
      expect(notices, isEmpty);
    },
  );
}
