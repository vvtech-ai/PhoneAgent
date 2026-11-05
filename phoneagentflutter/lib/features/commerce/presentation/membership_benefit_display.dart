/// Presentation only. These options never authorize calls or other features.
class MembershipBenefitDisplay {
  MembershipBenefitDisplay(Map<String, Object?> benefits)
    : _options = benefits['displayOptions'];
  final Object? _options;

  Map? _entry(String key) {
    final options = _options;
    if (options is! Map) return null;
    final value = options[key];
    return value is Map ? value : null;
  }

  bool large(String key) => _entry(key)?['fontSize'] == 'LARGE';
  bool visible(String key) => _entry(key)?['visible'] == true;
}
