import 'clone_creation.dart';
import 'clone_entitlement.dart';

String? cloneAdmissionError(int? price, int balance) {
  if (price == null || price <= 0) return '暂时无法获取声音克隆价格，请稍后重试';
  return balance < price ? '积分不足，声音克隆需要 ✦$price' : null;
}

/// Validate a fresh directory without changing the user-confirmed quote.
Future<String?> refreshedCloneAdmission(
  CloneCreationModel quoted, {
  Future<List<CloneCreationModel>> Function()? models,
  required Future<int> Function() points,
  required bool Function() isCurrent,
}) async {
  if (models != null) {
    final directory = await models();
    if (!isCurrent()) return '当前流程已失效';
    final matches = directory.where((m) => m.id == quoted.id);
    if (matches.length == 1) {
      switch (cloneEntitlement(matches.single)) {
        case CloneEntitlement.denied:
          return '暂无声音克隆权益，请返回后前往会员页查看并升级';
        case CloneEntitlement.unknown:
          return cloneEntitlementUnavailable;
        case CloneEntitlement.allowed:
          break;
      }
    }
    if (matches.length != 1 || !matches.single.available) {
      return '当前模型暂不可用，请返回重新选择';
    }
    if (matches.single.pricePoints != quoted.pricePoints) {
      return '克隆价格已更新，请返回重新选择模型确认';
    }
  }
  if (!isCurrent()) return '当前流程已失效';
  final balance = await points();
  return cloneAdmissionError(quoted.pricePoints, balance);
}
