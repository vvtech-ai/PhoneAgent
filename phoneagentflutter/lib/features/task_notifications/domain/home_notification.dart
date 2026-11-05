import '../../tasks/domain/task_records.dart';

class HomeNotification {
  const HomeNotification({
    required this.id,
    required this.text,
    required this.record,
  });
  final String id, text;
  final TaskRecord record;
  TaskStatus get status => _notificationStatus(record);
}

abstract interface class HomeNotificationReadStore {
  Future<Map<String, int>> load();
  Future<void> save(Map<String, int> readAtMillis);
}

/// The input retains source rows independently of the task catalog's call merge.
List<HomeNotification> homeNotificationCandidates(
  List<TaskRecord> records, {
  DateTime? now,
}) {
  final currentTime = now ?? DateTime.now();
  final candidates = <(int, HomeNotification)>[];
  for (final (index, row) in records.indexed) {
    final id = switch (row.kind) {
      TaskRecordKind.conversation when row.status == TaskStatus.completed =>
        _identity('conversation', row.sessionId),
      TaskRecordKind.legacyTask when _knownLegacyStatus(row.rawStatus) =>
        _identity('legacy_task', row.taskId),
      TaskRecordKind.translation when row.status != TaskStatus.running =>
        _identity('realtime_translation_call', row.callId),
      _ => '',
    };
    if (id.isEmpty) continue;
    candidates.add((
      index,
      HomeNotification(id: id, text: _text(row, currentTime), record: row),
    ));
  }
  candidates.sort((a, b) {
    final time = b.$2.record.sortTime.compareTo(a.$2.record.sortTime);
    return time == 0 ? a.$1.compareTo(b.$1) : time;
  });
  final dedupe = <String>{};
  final identities = <String>{};
  return List.unmodifiable(
    candidates.map((e) => e.$2).where((item) {
      final key = '${item.text}\u0000${item.record.sessionId?.trim() ?? ''}';
      return identities.add(item.id) && dedupe.add(key);
    }),
  );
}

List<HomeNotification> pendingHomeNotifications(
  List<HomeNotification> candidates,
  Map<String, int> readAtMillis,
) => List.unmodifiable(
  candidates.where((item) => !readAtMillis.containsKey(item.id)),
);

Map<String, int> pruneHomeNotificationReads(
  Map<String, int> entries,
  Set<String> protectedIds,
  int nowMillis,
) {
  final cutoff = nowMillis - const Duration(days: 90).inMilliseconds;
  final retained =
      entries.entries
          .where(
            (e) =>
                e.key.isNotEmpty &&
                e.value >= 0 &&
                (protectedIds.contains(e.key) || e.value >= cutoff),
          )
          .toList()
        ..sort((a, b) => b.value.compareTo(a.value));
  final result = <String, int>{};
  for (final entry in retained) {
    if (result.length < 512 || protectedIds.contains(entry.key)) {
      result[entry.key] = entry.value;
    }
  }
  return Map.unmodifiable(result);
}

String _identity(String source, String? value) {
  final id = value?.trim() ?? '';
  return id.isEmpty ? '' : '$source:$id';
}

TaskStatus _notificationStatus(TaskRecord row) =>
    row.kind == TaskRecordKind.translation ? TaskStatus.completed : row.status;

bool _knownLegacyStatus(String raw) {
  final value = raw.trim().toUpperCase();
  if (value == 'ERROR' ||
      value.endsWith('_ERROR') ||
      const {
        'NETWORK',
        'TIMEOUT',
        'SIP_ERROR',
        'PHONE_AGENT_ERROR',
        'MODEL_ERROR',
        'SERVICE_UNAVAILABLE',
      }.contains(value)) {
    return true;
  }
  return const {
    'COMPLETED',
    'COMPLETE',
    'SUCCESS',
    'SUCCEEDED',
    'DONE',
    'FINISHED',
    'INCOMPLETE',
    'FAILED',
    'FAIL',
    'CANCELED',
    'CANCELLED',
    'CLOSED',
    'UNCLEAR',
    'USER_INTERRUPTED',
    'EXECUTION_ERROR',
    'NETWORK_ERROR',
    'PARTIAL',
    'NEEDS_RECALL',
    'NO_ANSWER',
    'BUSY',
    'REJECTED',
    'CALLING',
    'RUNNING',
    'ACTIVE',
    'IN_PROGRESS',
    'PROCESSING',
    'EXECUTING',
    'WAITING_EXTERNAL_RESULT',
    'CONFIRMING',
    'PENDING',
    'WAITING',
    'WAITING_CONFIRM',
    'READY',
    'READY_TO_EXECUTE',
    'INIT',
    'SCENE_IDENTIFIED',
    'COLLECTING',
    'COLLECTING_REQUIRED_INFO',
    'SEARCH_RESTAURANTS',
    'USER_MODIFIED_REQUEST',
    '已完成',
    '执行异常',
    '未完成',
    '失败',
    '已取消',
    '已终止',
    '进行中',
    '待确认',
  }.contains(value);
}

String _text(TaskRecord row, DateTime now) {
  final scene = row.kind == TaskRecordKind.translation
      ? '实时翻译 · ${row.title.trim().isNotEmpty
            ? row.title.trim()
            : row.phoneNumber.trim().isNotEmpty
            ? row.phoneNumber.trim()
            : '未知号码'}'
      : _scene(row.scene, row.title);
  final status = switch (_notificationStatus(row)) {
    TaskStatus.completed => '已完成',
    TaskStatus.incomplete => '未完成',
    TaskStatus.running => '进行中',
    TaskStatus.executionError => '执行异常',
  };
  if (row.kind == TaskRecordKind.translation) {
    return '$scene$status：${_translationTime(row.timestamp, now)}';
  }
  var target = row.title.trim();
  for (final prefix in [
    '订餐厅 ·',
    '订酒店 ·',
    '订机票 ·',
    '会议通知 ·',
    '大型会议邀请 ·',
    '会议邀请 ·',
    '活动邀约 ·',
    '销售推荐 ·',
    '批量邀约 ·',
    '道歉 ·',
    '挪车 ·',
    '转达留言 ·',
    'AI 任务 ·',
    'AI 任务',
  ]) {
    if (target.startsWith(prefix)) {
      target = target.substring(prefix.length).trim();
      break;
    }
  }
  if (target.startsWith(scene)) target = target.substring(scene.length).trim();
  target = target.split(RegExp('[，。；;\n]')).first.trim();
  if (target.isEmpty ||
      const {'餐厅', '酒店', '任务', '目标对象', '进行中的对话'}.contains(target)) {
    target = switch (scene) {
      '订餐厅' => '餐厅',
      '订酒店' => '酒店',
      '订机票' => '航班',
      '会议通知' || '会议邀请' => '参会人',
      _ => '目标对象',
    };
  }
  target = _limit(target, 22);
  final parts = <String>[];
  for (final raw in [row.summary, row.title]) {
    for (final part in raw.replaceAll(RegExp('[\n；。]'), '·').split('·')) {
      final value = part.trim();
      if (value.isEmpty ||
          RegExp(r'^\d{4}-\d{2}-\d{2}[T ].*$').hasMatch(value) ||
          value.contains('任务已同步') ||
          value.contains('等待进一步处理')) {
        continue;
      }
      final short = _limit(value, 36);
      if (!parts.contains(short)) parts.add(short);
      if (parts.length == 4) break;
    }
    if (parts.length == 4) break;
  }
  final keyInfo = parts.isEmpty ? '任务信息已同步' : parts.join(' · ');
  final body = [target, if (target != keyInfo) keyInfo].join(' · ');
  return '$scene$status：$body';
}

String _limit(String text, int length) =>
    String.fromCharCodes(text.runes.take(length));

String _scene(String raw, String title) {
  const names = {
    '订餐厅',
    '订酒店',
    '订机票',
    '会议邀请',
    '大型会议邀请',
    '活动邀约',
    '销售推荐',
    '批量邀约',
    '道歉',
    '挪车',
    '转达留言',
  };
  if (names.contains(raw.trim())) return raw.trim();
  final scene = raw.trim().toUpperCase();
  if (scene == 'FOOD_ORDERING' || scene == 'RESTAURANT_BOOKING') return '订餐厅';
  if (scene == 'HOTEL_BOOKING') return '订酒店';
  if (scene == 'FLIGHT_BOOKING') return '订机票';
  if (scene.contains('MEETING')) return '会议通知';
  if (scene == 'AI_CALL') return 'AI 通话';
  if (['会议', '参会', '回执', '邀请', '通知'].any(title.contains)) return '会议通知';
  if (['酒店', '入住', '离店', '房型', '无烟房'].any(title.contains)) return '订酒店';
  if (['机票', '航班', '出发', '目的地', '舱位'].any(title.contains)) return '订机票';
  if ([
    '餐厅',
    '订餐',
    '订位',
    '包房',
    '包间',
    '低消',
    '海底捞',
    '新荣记',
    '西堤',
  ].any(title.contains)) {
    return '订餐厅';
  }
  return 'AI 通话';
}

String _translationTime(String timestamp, DateTime now) {
  final date = DateTime.tryParse(timestamp)?.toLocal();
  if (date == null) return '刚刚';
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(date.year, date.month, date.day);
  final delta = today.difference(day).inDays;
  final dayLabel = delta == 0
      ? '今天'
      : delta == 1
      ? '昨天'
      : delta > 1 && delta < 7
      ? const ['星期一', '星期二', '星期三', '星期四', '星期五', '星期六', '星期日'][date.weekday -
            1]
      : date.year == now.year
      ? '${date.month}月${date.day}日'
      : '${date.year}年${date.month}月${date.day}日';
  final time =
      '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  return '$dayLabel $time';
}
