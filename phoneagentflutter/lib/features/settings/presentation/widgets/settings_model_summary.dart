/// Mirrors effective native compact names; missing pricing stays missing.
String settingsModelSummary(String title, double? multiplier) {
  final name = title.trim();
  if (name.isEmpty) return '';
  final ascii = RegExp(r'^[A-Za-z0-9]+').firstMatch(name)?.group(0);
  final runes = (ascii ?? name).runes.toList();
  final prefix = String.fromCharCodes(runes.take(ascii == null ? 4 : 8));
  final price = multiplier != null && multiplier.isFinite && multiplier > 0
      ? ' ×${multiplier.toStringAsFixed(1)}'
      : '';
  return '$prefix…$price';
}
