/// Shared native record label. Parsing and formatting never alter record data.
String recordTimeLabel(
  String raw, {
  DateTime? now,
  String invalidFallback = '',
}) {
  final date = DateTime.tryParse(raw)?.toLocal();
  if (date == null) return invalidFallback;
  final current = (now ?? DateTime.now()).toLocal();
  // UTC dates are calendar ordinals only, independent of daylight-saving hours.
  final day = DateTime.utc(date.year, date.month, date.day);
  final today = DateTime.utc(current.year, current.month, current.day);
  final difference = today.difference(day).inDays;
  const weekdays = ['星期一', '星期二', '星期三', '星期四', '星期五', '星期六', '星期日'];
  final prefix = difference == 0
      ? '今天'
      : difference == 1
      ? '昨天'
      : day.isAfter(today.subtract(const Duration(days: 7)))
      ? weekdays[date.weekday - 1]
      : date.year == current.year
      ? '${date.month}月${date.day}日'
      : '${date.year}年${date.month}月${date.day}日';
  String pad(int value) => value.toString().padLeft(2, '0');
  return '$prefix ${pad(date.hour)}:${pad(date.minute)}';
}
