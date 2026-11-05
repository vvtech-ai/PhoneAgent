/// Model access comes from published benefits; names come from the model catalog.
class MembershipModelLabels {
  MembershipModelLabels({
    required Map<String, Object?> benefits,
    required Map<String, String> names,
    Map<String, Object?>? freeBenefits,
  }) {
    final allowed = _ids(benefits);
    final free = _ids(freeBenefits);
    for (final id in allowed) {
      final name = names[id]?.trim();
      if (name == null || name.isEmpty) {
        unresolved = true;
      } else if (freeBenefits != null && !free.contains(id)) {
        exclusive.add(name);
      } else {
        shared.add(name);
      }
    }
  }
  final exclusive = <String>{}, shared = <String>{};
  bool unresolved = false;

  static Set<String> _ids(Map<String, Object?>? benefits) => {
    for (final entry in benefits?['modelEntitlements'] as List? ?? const [])
      if (entry is Map &&
          (entry['capability'] == null ||
              entry['capability'] == 'REALTIME_VOICE') &&
          entry['modelId'] is String)
        entry['modelId'] as String,
  };

  String get title => exclusive.isEmpty
      ? '可用模型${shared.isEmpty ? '' : ' ${shared.join('、')}'}'
      : '会员专属模型 ${exclusive.join('、')}';
  String get detail => unresolved
      ? '部分模型名称暂未加载，请刷新重试'
      : exclusive.isNotEmpty && shared.isNotEmpty
      ? '同时支持 ${shared.join('、')}'
      : exclusive.isNotEmpty || shared.isNotEmpty
      ? '支持以上模型通话'
      : '当前权益未开放';
}
