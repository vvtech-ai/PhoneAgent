/// Matches native ConnectedDurationDisplayPolicy; display only, never billing.
int translationConnectedSeconds(int durationMillis) {
  if (durationMillis <= 0) return 0;
  final seconds = durationMillis ~/ 1000 + (durationMillis % 1000 == 0 ? 0 : 1);
  return seconds > 2147483647 ? 2147483647 : seconds;
}
