/// Synthetic display-only snapshot; no backend, contacts or telephone port.
abstract final class ShellBatchConfirmation {
  static Map<String, Object?> request(String id) => {
    'toolCallId': id,
    'toolName': 'confirmBatchTask',
    'ordinal': 0,
    'displayPayloadVersion': 1,
    'assistantText': '请确认以上任务理解，确认后我再开始执行。',
    'arguments': {'snapshotJson': snapshot},
  };
  static Map<String, Object?> get snapshot => {
    'title': 'MOCK · 大型会议邀请',
    'sections': [
      {
        'title': '任务信息',
        'rows': [
          {'label': '会议', 'value': '合成迁移评审'},
          {'label': '时间', 'value': '明天下午三点'},
        ],
      },
      {
        'title': '补充信息',
        'rows': [
          {'label': '地点', 'value': '线上会议'},
        ],
      },
    ],
    'recipients': [
      for (var i = 1; i <= 5; i++)
        {
          'itemId': 'r$i',
          'targetName': '合成联系人$i',
          'phoneNumber': '+1202555010$i',
          'salutation': '您好',
          'status': 'READY',
          'detail': 'MOCK · 不拨号',
        },
    ],
    'issues': [
      {'title': '合成联系人6', 'detail': '缺少号码，暂不执行'},
    ],
    'rules': [
      {'label': '确认事项', 'value': '是否参加；没有真实电话'},
    ],
    'contactSummary': {
      'originalCount': 6,
      'callableCount': 5,
      'skippedCount': 1,
    },
  };
  static Map<String, Object?> execution(String sessionId) => {
    'toolCallId': 'mock-execute:$sessionId',
    'toolName': 'makeBatchCalls',
    'arguments': {
      'primaryGoal': '合成迁移评审',
      'recipientsJson': snapshot['recipients'],
    },
  };
  static String decision(String? message) => switch (message) {
    '确认' => 'CONFIRMED',
    '取消' => 'CANCELLED',
    _ => 'REVISION_REQUESTED',
  };
}
