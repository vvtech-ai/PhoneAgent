import 'commerce_catalog.dart';

/// Advisory copy from server snapshots; never authorizes or blocks an action.
class MembershipAccessHint {
  const MembershipAccessHint(this.allowed, this.message);
  final bool? allowed;
  final String message;

  static MembershipAccessHint model({
    required Map<String, Object?>? current,
    required Map<String, Map<String, Object?>> published,
    required String modelId,
    String? currentLevel,
  }) {
    bool? permits(Map<String, Object?>? benefits) {
      final entries = benefits?['modelEntitlements'];
      if (entries is! List) return null;
      return entries.any(
        (item) =>
            item is Map &&
            item['modelId'] == modelId &&
            item['capability'] == 'REALTIME_VOICE',
      );
    }

    final allowed = permits(current);
    if (allowed == null) {
      return const MembershipAccessHint(null, '');
    }
    if (allowed) return const MembershipAccessHint(true, '');
    final levels = membershipLevels
        .where((level) => level != 'FREE' && permits(published[level]) == true)
        .toList();
    final first = levels.isEmpty ? -1 : membershipLevels.indexOf(levels.first);
    final suffix =
        first >= 0 && membershipLevels.skip(first).every(levels.contains);
    final required = suffix && levels.length > 1
        ? '${membershipName(levels.first)}及以上会员可用'
        : '${levels.map(membershipName).join('、')}会员可用';
    return MembershipAccessHint(
      false,
      levels.contains(currentLevel)
          ? '当前套餐未包含此模型，请查看会员权益'
          : levels.isEmpty
          ? '暂无可用会员套餐'
          : required,
    );
  }
}
