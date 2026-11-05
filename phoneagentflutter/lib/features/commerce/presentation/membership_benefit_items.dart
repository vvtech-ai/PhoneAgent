import 'membership_benefit_display.dart';
import 'membership_model_labels.dart';
import 'widgets/commerce_display_format.dart';

/// A read-only presentation row. Copy never grants a functional entitlement.
class MembershipBenefitItem {
  const MembershipBenefitItem({
    required this.id,
    required this.title,
    required this.description,
    this.large = false,
    this.highlight,
  });

  final String id, title, description;
  final bool large;
  final String? highlight;
}

List<MembershipBenefitItem> membershipBenefitItems({
  required String level,
  required Map<String, Object?> benefits,
  Map<String, String> modelNames = const {},
  Map<String, Object?>? freeBenefits,
}) {
  final display = MembershipBenefitDisplay(benefits);
  MembershipBenefitItem row(String id, String title, String description) =>
      MembershipBenefitItem(
        id: id,
        title: title,
        description: description,
        large: display.large(id),
      );
  final monthly =
      (benefits['monthlyBasePoints'] as int? ?? 0) +
      (benefits['monthlyBonusPoints'] as int? ?? 0);
  final items = <MembershipBenefitItem>[
    if (level != 'FREE')
      MembershipBenefitItem(
        id: 'monthlyPoints',
        title: '每月到账 ${displayPoints(monthly)} 积分',
        description:
            '其中含赠送 ${displayPoints(benefits['monthlyBonusPoints'] as int? ?? 0)} 积分',
        large: display.large('monthlyPoints'),
        highlight: displayPoints(monthly),
      ),
  ];
  final custom = benefits['displayItems'];
  if (custom is List) {
    for (final item in custom) {
      if (item is! Map ||
          item['id'] is! String ||
          item['id'] == 'monthlyPoints' ||
          item['title'] is! String) {
        continue;
      }
      items.add(
        MembershipBenefitItem(
          id: item['id'] as String,
          title: item['title'] as String,
          description: item['description'] as String? ?? '',
          large: item['fontSize'] == 'LARGE',
        ),
      );
    }
    return items;
  }
  return [
    ...items,
    ..._legacyItems(benefits, modelNames, freeBenefits, level, row),
  ];
}

List<MembershipBenefitItem> _legacyItems(
  Map<String, Object?> benefits,
  Map<String, String> names,
  Map<String, Object?>? freeBenefits,
  String level,
  MembershipBenefitItem Function(String, String, String) row,
) {
  final batch = benefits['batchEnabled'] == true;
  final concurrency = benefits['concurrentCallLimit'];
  final discount = benefits['packDiscountBps'] as num?;
  final models = MembershipModelLabels(
    benefits: benefits,
    names: names,
    freeBenefits: freeBenefits,
  );
  final display = MembershipBenefitDisplay(benefits);
  return [
    if (concurrency != null)
      row(
        'batchCalls',
        batch
            ? '${benefits['batchContactLimit'] ?? '—'} 人批量联系人任务'
            : '单路 Agent 外呼',
        batch ? '最多 $concurrency 路同时外呼' : '未接通不扣积分',
      ),
    row('models', models.title, models.detail),
    row(
      'voiceClone',
      '声音克隆',
      benefits['cloneEntitlements'] is Map &&
              (benefits['cloneEntitlements'] as Map)['enabled'] == true
          ? '支持'
          : '暂不支持',
    ),
    if (level == 'FREE') row('singleCall', '单人通话任务', '批量联系人任务需开通会员'),
    if (display.visible('priorityLine'))
      row('priorityLine', '高峰极速优先线路', '高峰时段优先分配通话线路'),
    if (display.visible('newModelPreview'))
      row('newModelPreview', '新模型抢先体验', '优先体验新上线模型'),
    if (discount != null && discount < 10000)
      row(
        'packDiscount',
        '积分包${(discount / 1000).toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')}折优惠',
        '实际支付享折扣，到账积分不变',
      ),
  ];
}
