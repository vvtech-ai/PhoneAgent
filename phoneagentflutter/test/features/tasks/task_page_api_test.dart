import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/network/account_session.dart';
import 'package:phone_agent/features/tasks/data/api_task_repository.dart';
import 'package:phone_agent/features/tasks/domain/task_page.dart';
import '../../support/synthetic_account_api.dart';

Map<String, Object?> item(String type, String id) => {
  'resourceType': type,
  'resourceId': id,
  'title': '任务',
  'status': 'UNCLEAR',
  'detail': '结果未确认',
  'sceneType': 'AI_CALL',
  'createdAt': '2026-10-08',
  'canDelete': false,
  'deleteBlockCode': 'TASK_DIALING_DELETE_BLOCKED',
  'unreadResult': true,
};
void main() {
  test(
    'pin maps target response and rejects wrong identity or pin state',
    () async {
      final wire = SyntheticAccountApi();
      final repo = ApiTaskRepository(wire.api, 'a');
      const ref = TaskRef(TaskResourceType.agentConversation, 'a');
      wire.data = item('AGENT_CONVERSATION', 'a')..['pinnedAt'] = '2026-10-09';
      final target = await repo.updatePin(ref, true);
      expect(target.ref?.key, ref.key);
      expect(target.pinnedAt, '2026-10-09');
      wire.data = item('AGENT_CONVERSATION', 'other')
        ..['pinnedAt'] = '2026-10-09';
      await expectLater(
        repo.updatePin(ref, true),
        throwsA(ApiFailure.invalidResponse),
      );
      wire.data = item('AGENT_CONVERSATION', 'a');
      await expectLater(
        repo.updatePin(ref, true),
        throwsA(ApiFailure.invalidResponse),
      );
      final unpinned = await repo.updatePin(ref, false);
      expect(unpinned.pinnedAt, isNull);
    },
  );
  test(
    'unified wire fields preserve native identity flags and server order',
    () async {
      final wire = SyntheticAccountApi()
        ..data = {
          'pinnedItems': [
            item('AGENT_CONVERSATION', 'p')..['pinnedAt'] = '2026-10-08',
          ],
          'items': [
            item('LEGACY_TASK', 'l'),
            item('REALTIME_TRANSLATION', 't'),
          ],
          'nextOffset': 15,
          'hasMore': true,
          'hasUnread': true,
        };
      final repo = ApiTaskRepository(wire.api, 'a');
      final page = await repo.loadPage();
      expect(page.pinnedItems.single.sessionId, 'p');
      expect(page.items.first.taskId, 'l');
      expect(page.items.last.callId, 't');
      expect(page.pinnedItems.single.canDelete, false);
      expect(page.pinnedItems.single.unreadResult, true);
      final pageRequest = wire.requests.first;
      expect(pageRequest.uri.path, '/api/assistant/task-list/page');
      expect(wire.requests.last.uri.path, '/api/task/call-history');
      expect(pageRequest.uri.queryParameters, {
        'offset': '0',
        'limit': '15',
        'userId': 'a',
      });
      expect(pageRequest.headers['Authorization'], 'Bearer synthetic');
      wire.data = null;
      const ref = TaskRef(TaskResourceType.agentConversation, 'p');
      await repo.pin(ref, true);
      await repo.markRead(ref);
      await repo.hide(ref);
      await repo.clearUnread();
      expect(wire.requests.map((r) => r.method), [
        'GET',
        'GET',
        'PUT',
        'PUT',
        'DELETE',
        'PUT',
      ]);
      expect(wire.requests[2].data, {'pinned': true});
      expect(
        wire.requests[3].uri.path,
        '/api/assistant/task-list/items/AGENT_CONVERSATION/p/read',
      );
      expect(wire.requests[3].method, 'PUT');
      expect(
        wire.requests.last.uri.path,
        '/api/assistant/task-list/read/clear',
      );
    },
  );
  test(
    'account changed and invalid identity cannot send task mutations',
    () async {
      final wire = SyntheticAccountApi(),
          repo = ApiTaskRepository(SyntheticAccountApi().api, 'a');
      await expectLater(
        repo.hide(const TaskRef(TaskResourceType.legacyTask, '../bad')),
        throwsA(ApiFailure.invalidResponse),
      );
      final owned = ApiTaskRepository(wire.api, 'a');
      wire.credentials = const AccountCredentials('b', 'synthetic', 2);
      await expectLater(owned.loadPage(), throwsA(ApiFailure.sessionChanged));
      expect(wire.requests, isEmpty);
    },
  );
  test(
    'markRead keeps the agent conversation route and propagates failures',
    () async {
      final wire = SyntheticAccountApi();
      final repo = ApiTaskRepository(wire.api, 'a');
      const ref = TaskRef(
        TaskResourceType.agentConversation,
        'session_23772-2026101506',
      );

      await repo.markRead(ref);
      expect(wire.requests.single.method, 'PUT');
      expect(
        wire.requests.single.uri.path,
        '/api/assistant/task-list/items/AGENT_CONVERSATION/session_23772-2026101506/read',
      );

      wire.status = 503;
      await expectLater(repo.markRead(ref), throwsA(ApiFailure.rejected));
    },
  );
}
