import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/tasks/domain/task_details.dart';
import 'package:phone_agent/features/tasks/domain/task_records.dart';
import 'package:phone_agent/features/tasks/presentation/controller/task_detail_controller.dart';
import 'package:phone_agent/features/conversation/domain/history/conversation_history.dart';
import 'package:phone_agent/features/conversation/domain/history/ledger_event.dart';

class History implements ConversationHistoryRepository {
  int reads = 0;
  Completer<RestoredConversation> pending = Completer();
  @override
  Future<RestoredConversation> restore(String id) {
    expect(id, 'same');
    reads++;
    return pending.future;
  }
}

class Legacy implements TaskDetailRepository {
  @override
  Future<LegacyTaskDetail> load(String id) async => throw StateError('unused');
}

const row = TaskRecord(
  id: 'row',
  kind: TaskRecordKind.conversation,
  title: 'old',
  status: TaskStatus.running,
  rawStatus: 'RUNNING',
  sessionId: 'same',
);
void main() {
  test(
    'detail preserves terminal identity and failure is retryable without tool replay',
    () async {
      final history = History();
      final owner = TaskDetailController(row, history, Legacy());
      final first = owner.load();
      await owner.load();
      expect(history.reads, 1);
      history.pending.completeError(TimelineFailure.unavailable);
      await first;
      expect(owner.state.failed, true);
      expect(owner.state.canRestore, false);
      history.pending = Completer();
      final retry = owner.load();
      history.pending.complete(
        const RestoredConversation(
          ConversationDetail(
            sessionId: 'same',
            title: 'server',
            status: 'COMPLETED',
          ),
        ),
      );
      await retry;
      expect(owner.state.title, 'server');
      expect(owner.state.rawStatus, 'COMPLETED');
      expect(owner.state.canRestore, true);
      expect(owner.state.record.sessionId, 'same');
      owner.dispose();
    },
  );
  test('disposed account does not publish late history', () async {
    final history = History();
    final c = TaskDetailController(row, history, Legacy());
    final load = c.load();
    c.dispose();
    history.pending.complete(
      const RestoredConversation(
        ConversationDetail(sessionId: 'same', title: 'late', status: 'RUNNING'),
      ),
    );
    await load;
  });
}
