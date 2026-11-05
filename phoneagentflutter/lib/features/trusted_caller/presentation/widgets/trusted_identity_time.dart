String trustedIdentityTime(String raw) {
  if (raw.isEmpty) return '本次';
  final number = double.tryParse(raw);
  if (number == null || !number.isFinite) return raw;
  final milliseconds = number > 10000000000 ? number : number * 1000;
  try {
    final time = DateTime.fromMillisecondsSinceEpoch(milliseconds.round());
    String two(int value) => value.toString().padLeft(2, '0');
    return '${time.year}年${two(time.month)}月${two(time.day)}日 '
        '${two(time.hour)}:${two(time.minute)}';
  } on RangeError {
    return raw;
  }
}
