/// Exact endpoint-specific reasons only; arbitrary server text stays private.
abstract final class MemoryApiFailurePolicy {
  static String? message(Object? code, Object? message) {
    if (code != 'AC0001' && code != 'AC0005') return null;
    return message is String && _reasons.contains(message) ? message : null;
  }

  static const _reasons = {
    '记忆容量已满，请先精简或删除已有记忆',
    '记忆内容不能为空',
    '请至少选择一个适用任务',
    '该任务暂不可选，请重新选择适用任务',
    '适用任务不能为空',
    '请选择记忆操作',
    '不支持的记忆操作',
    '请选择是否启用记忆',
    '该条记忆已不存在，请刷新后重试',
    '记忆未保存，请刷新后重试',
    '同一记忆操作不能提交不同内容，请重新操作',
  };
}
