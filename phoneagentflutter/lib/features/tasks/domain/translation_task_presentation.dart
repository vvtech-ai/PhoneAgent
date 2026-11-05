import '../../../core/domain/record_time.dart';
import 'task_records.dart';

/// Matches the Android translation card title and duration policies.
class TranslationTaskPresentation {
  static String historyTitle(TaskRecord history) {
    var title = history.title;
    for (final prefix in ['翻译通话 ', '拨打 ']) {
      if (title.startsWith(prefix)) {
        title = title.substring(prefix.length);
        break;
      }
    }
    title = title.trim();
    if (const {'未知联系人', '未知对象', '目标对象', '对方'}.contains(title)) {
      title = '';
    }
    if (title.isEmpty) title = history.phoneNumber.trim();
    return '实时翻译 · ${title.isEmpty ? '未知号码' : title}';
  }

  static String historySubtitle(TaskRecord history, {DateTime? now}) {
    final time = _instant(history.startedAt) != null
        ? history.startedAt
        : history.timestamp;
    if (_instant(time) == null) return '刚刚';
    return recordTimeLabel(time, now: now);
  }

  static DateTime? _instant(String raw) =>
      RegExp(r'^\d{4}-\d{2}-\d{2}[ T]\d{2}:\d{2}').hasMatch(raw.trim())
      ? DateTime.tryParse(raw.trim())
      : null;

  static String duration(TaskRecord row) {
    if (row.durationMillis case final int value) return format(value);
    final existing = row.rawStatus.trim();
    if (RegExp(r'^\d{2,}:\d{2}(?::\d{2})?$').hasMatch(existing)) {
      return existing;
    }
    final start = _instant(row.startedAt);
    final end = _instant(row.timestamp);
    return start == null || end == null
        ? ''
        : format(end.difference(start).inMilliseconds);
  }

  static String format(int milliseconds) {
    final seconds = (milliseconds ~/ 1000).clamp(0, 1099511627776);
    String p(int value) => value.toString().padLeft(2, '0');
    return seconds >= 3600
        ? '${p(seconds ~/ 3600)}:${p(seconds ~/ 60 % 60)}:${p(seconds % 60)}'
        : '${p(seconds ~/ 60)}:${p(seconds % 60)}';
  }
}
