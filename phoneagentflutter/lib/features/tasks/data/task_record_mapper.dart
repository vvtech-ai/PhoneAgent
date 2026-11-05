import '../../../core/network/account_api.dart';
import '../../../core/network/account_session.dart';
import '../domain/task_records.dart';

class TaskRecordMapper {
  const TaskRecordMapper();
  List<TaskRecord> decode(Object? value, TaskSource source) {
    if (value is! List) throw ApiFailure.invalidResponse;
    return List.unmodifiable(
      value
          .map(AccountApi.object)
          .map((dto) => _record(dto, source))
          .whereType<TaskRecord>(),
    );
  }

  TaskRecord? _record(Map<String, Object?> dto, TaskSource source) {
    String field(String key) {
      final value = dto[key];
      if (value != null && value is! String) throw ApiFailure.invalidResponse;
      return (value as String? ?? '').trim();
    }

    String requiredId(String key) {
      final id = field(key);
      if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(id)) {
        throw ApiFailure.invalidResponse;
      }
      return id;
    }

    String first(List<String> keys) =>
        keys.map(field).firstWhere((v) => v.isNotEmpty, orElse: () => '');
    if (source == TaskSource.conversations) {
      final id = requiredId('sessionId'), raw = field('status');
      return TaskRecord(
        id: 'conversation:$id',
        kind: TaskRecordKind.conversation,
        sessionId: id,
        taskId: field('taskId').isEmpty ? null : field('taskId'),
        title: field('title').isEmpty ? 'AI 通话' : field('title'),
        status: status(raw),
        rawStatus: raw,
        scene: _skills[field('activeSkillId')] ?? field('sceneType'),
        timestamp: first(['updatedAt', 'createdAt']),
      );
    }
    if (source == TaskSource.legacyTasks) {
      final raw = field('status').toUpperCase();
      // Despite its name, v65 isTerminalTask only includes successful terminal tasks.
      if (!const {
        'COMPLETED',
        'DONE',
        'FINISHED',
        'SUCCESS',
        'SUCCEEDED',
      }.contains(raw)) {
        return null;
      }
      final id = requiredId('taskId');
      return TaskRecord(
        id: 'task:$id',
        taskId: id,
        kind: TaskRecordKind.legacyTask,
        title: first(['originText', 'taskId']),
        status: TaskStatus.completed,
        rawStatus: raw,
        scene: field('sceneType'),
        timestamp: field('createdAt'),
        summary: first(['callResultText', 'finalResult']),
      );
    }
    final raw = first(['callState', 'resultCode']).toUpperCase();
    if (!const {
          'COMPLETED',
          'SUCCESS',
          'DONE',
          'FINISHED',
          'ENDED',
          'FAILED',
          'CANCELLED',
          'REJECTED',
          'NOT_FOUND',
        }.contains(raw) &&
        !['FAIL', 'CANCEL', 'REJECT'].any(raw.contains)) {
      return null;
    }
    final call = requiredId('callId'), attempt = field('callAttemptId');
    final task = field('taskId').isEmpty ? call : field('taskId');
    final failed = ['FAIL', 'CANCEL', 'REJECT', 'NOT_FOUND', 'NEEDS_RECALL']
        .any(
          (v) =>
              raw.contains(v) || field('resultCode').toUpperCase().contains(v),
        );
    final duration = dto['durationMillis'];
    if (duration != null && duration is! int) throw ApiFailure.invalidResponse;
    final translation =
        field('sceneType').toUpperCase() == 'REALTIME_TRANSLATION';
    final target = field('targetName');
    final historyTitle =
        const {'', '对方', 'AI通话', 'AI 通话', '目标对象', '未知对象'}.contains(target)
        ? (field('phoneNumber').isEmpty ? 'AI通话' : field('phoneNumber'))
        : target;
    return TaskRecord(
      id: 'call:${attempt.isEmpty ? call : attempt}',
      kind: translation ? TaskRecordKind.translation : TaskRecordKind.call,
      taskId: task,
      callId: call,
      title: translation
          ? historyTitle
          : first(['targetName', 'phoneNumber', 'callId']),
      rawStatus: raw,
      status: failed ? TaskStatus.incomplete : TaskStatus.completed,
      scene: field('sceneType'),
      startedAt: field('createdAt'),
      timestamp: first(['updatedAt', 'createdAt']),
      summary: first(['resultReason', 'statusMessage', 'dialogueSummary']),
      phoneNumber: field('phoneNumber'),
      dialogue: field('dialogueDetail'),
      durationMillis: duration as int?,
    );
  }

  static TaskStatus status(String raw) {
    final s = raw.trim().toUpperCase();
    if ([
          'NETWORK',
          'TIMEOUT',
          'SIP_ERROR',
          'PHONE_AGENT_ERROR',
          'MODEL_ERROR',
          'SERVICE_UNAVAILABLE',
          'HTTP_ERROR',
          'TECHNICAL',
          '网络异常',
          '网络错误',
          '执行异常',
          '模型服务异常',
          '外呼通道异常',
          '服务不可用',
          '连接失败',
          '真实 SIP 未启用',
          'PHONE AGENT 未 READY',
          '超时',
        ].any(s.contains) ||
        s == 'ERROR' ||
        s.endsWith('_ERROR')) {
      return TaskStatus.executionError;
    }
    if (s == 'USER_INTERRUPTED') return TaskStatus.running;
    if ([
      'INCOMPLETE',
      'FAIL',
      'CANCEL',
      'CLOSE',
      'UNCLEAR',
      'PARTIAL',
      'NEEDS_RECALL',
      'NO_ANSWER',
      'BUSY',
      'REJECT',
      '未完成',
      '部分完成',
      '未接通',
    ].any(s.contains)) {
      return TaskStatus.incomplete;
    }
    if (['COMPLET', 'SUCCESS', 'DONE', 'FINISH', '已完成'].any(s.contains)) {
      return TaskStatus.completed;
    }
    return TaskStatus.running;
  }

  static const _skills = {
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
