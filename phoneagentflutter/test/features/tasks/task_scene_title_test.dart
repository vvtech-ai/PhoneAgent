import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/tasks/data/api_task_scene_titles.dart';
import 'package:phone_agent/features/tasks/data/api_task_repository.dart';
import 'package:phone_agent/features/tasks/domain/task_scene_titles.dart';
import 'package:phone_agent/features/tasks/domain/task_record_presentation.dart';
import '../../support/synthetic_account_api.dart';
import 'task_page_api_test.dart' show item;
import 'task_pagination_test.dart' show row;

class _Titles implements TaskSceneTitleSource {
  var fail = false;
  @override
  Future<Map<String, String>> load() async {
    if (fail) throw StateError('offline');
    return {'s': '已发布活动邀约'};
  }
}

void main() {
  test(
    'catalog maps session custom title first, skill fallback and nullable title',
    () async {
      final wire = SyntheticAccountApi()
        ..data = [
          {
            'sessionId': 'a',
            'activeSkillTitle': ' 活动邀约新版 ',
            'activeSkillId': 'sales_recommendation',
          },
          {
            'sessionId': 'b',
            'activeSkillTitle': null,
            'activeSkillId': 'meeting_notification',
          },
          {
            'sessionId': 'c',
            'activeSkillTitle': '',
            'activeSkillId': 'unknown',
          },
        ];
      expect(await ApiTaskSceneTitles(wire.api, 'a').load(), {
        'a': '活动邀约新版',
        'b': '会议邀请',
      });
      expect(wire.requests.single.uri.path, '/api/agent/conversations');
      expect(wire.requests.single.uri.queryParameters['userId'], 'a');
    },
  );
  test(
    'metadata enriches existing SDK rows, failures retain labels, pin keeps title',
    () async {
      final wire = SyntheticAccountApi();
      final source = _Titles();
      final repo = ApiTaskRepository(wire.api, 'a', sceneTitles: source);
      wire.data = {
        'pinnedItems': [],
        'items': [item('AGENT_CONVERSATION', 's')],
        'nextOffset': 1,
        'hasMore': false,
        'hasUnread': true,
      };
      final first = await repo.loadPage();
      expect(first.items, hasLength(1));
      expect(first.items.single.sceneTitle, '已发布活动邀约');
      source.fail = true;
      expect((await repo.loadPage()).items.single.sceneTitle, '已发布活动邀约');
      wire.data = item('AGENT_CONVERSATION', 's')..['pinnedAt'] = '2026-10-09';
      expect(
        (await repo.updatePin(first.items.single.ref!, true)).sceneTitle,
        '已发布活动邀约',
      );
    },
  );
  test('native scene target title and relative time rules', () {
    final record = row('s').copyWith(title: '订餐任务 · 北海渔村', sceneTitle: '预约餐厅');
    expect(TaskRecordPresentation.title(record), '预约餐厅 · 北海渔村');
    expect(
      TaskRecordPresentation.time(
        '2026-10-06T18:00:00',
        now: DateTime(2026, 10, 9),
      ),
      '星期二 18:00',
    );
  });
}
