import 'account_memory.dart';

/// Local preflight only; the server still validates the current account limits.
abstract final class MemoryMutationValidation {
  static String? error(MemorySnapshot snapshot, MemoryAction action) {
    if (action.action != 'ADD' && action.action != 'UPDATE') return null;
    final content = action.content?.trim() ?? '';
    if (content.isEmpty) return '记忆内容不能为空';
    if (action.action == 'ADD' &&
        snapshot.entries.length >= snapshot.maxEntries) {
      return '记忆条数已满，请先删除已有记忆';
    }
    final length = content.runes.length;
    if (length > snapshot.maxCharacters) return '记忆内容过长，请缩短后保存';
    final original = snapshot.entries
        .where((entry) => entry.id == action.id)
        .firstOrNull;
    final previous = original?.content.runes.length ?? 0;
    if (snapshot.usedCharacters - previous + length > snapshot.maxCharacters) {
      return '记忆容量已满，请先精简或删除已有记忆';
    }
    if (action.scope == MemoryScope.selected) {
      final ids = action.skillIds ?? const [];
      if (ids.isEmpty) return '请至少选择一个适用任务';
      final enabled = snapshot.skills
          .where((skill) => skill.enabled)
          .map((skill) => skill.id)
          .toSet();
      if (ids.any(
        (id) =>
            !enabled.contains(id) &&
            !(original?.skillIds.contains(id) ?? false),
      )) {
        return '该任务暂不可选，请重新选择适用任务';
      }
    }
    return null;
  }
}
