/// Server billing display policy. This estimate never controls billing or spending.
abstract final class PointsPresentation {
  static String balance(int? value) => value == null
      ? '--'
      : (value < 0 ? 0 : value).toString().replaceAllMapped(
          RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (_) => ',',
        );
  static int? estimatedMinutes(int balance, {int? pointsPerMinute}) =>
      pointsPerMinute == null || pointsPerMinute <= 0
      ? null
      : (balance < 0 ? 0 : balance) ~/ pointsPerMinute;
}
