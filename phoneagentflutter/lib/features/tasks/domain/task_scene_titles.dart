import 'task_records.dart';
import 'task_page.dart';

abstract interface class TaskSceneTitleSource {
  Future<Map<String, String>> load();
}

/// Only enriches existing SDK rows. The conversation catalog is not a task source.
class TaskSceneTitles {
  static TaskRecord record(TaskRecord row, Map<String, String> titles) =>
      row.copyWith(sceneTitle: titles[row.sessionId] ?? row.sceneTitle);

  static TaskPage page(TaskPage page, Map<String, String> titles) => TaskPage(
    pinnedItems: [for (final row in page.pinnedItems) record(row, titles)],
    items: [for (final row in page.items) record(row, titles)],
    nextOffset: page.nextOffset,
    hasMore: page.hasMore,
    hasUnread: page.hasUnread,
  );

  static const skills = {
    'restaurant_booking': '订餐厅',
    'meeting_notification': '会议邀请',
    'meeting_notification_v2': '大型会议邀请',
    'business_event_invitation': '活动邀约',
    'sales_recommendation': '销售推荐',
    'batch_invitation': '批量邀约',
    'apology_master': '道歉',
    'parking_move_request': '挪车',
    'general_message_relay': '转达留言',
    'hotel_booking': '订酒店',
    'flight_booking': '订机票',
  };
}
