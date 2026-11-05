import 'package:flutter/material.dart';
import '../../../../core/design/native_confirmation_dialog.dart';
import '../../../commerce/domain/commerce_catalog.dart';
import 'clone_entitlement_dialog.dart';

/// Current rights admit entry; published benefits only describe upgrade options.
Future<bool> checkCloneEntryMembership(
  BuildContext context, {
  required Future<MembershipCurrent> Function() load,
  Future<CommerceCatalog> Function()? loadCatalog,
  required bool Function() isCurrent,
  required Future<void> Function() upgrade,
}) async {
  while (context.mounted && isCurrent()) {
    String? supportedLevels;
    String? currentMembership;
    try {
      final current = await load();
      if (!context.mounted || !isCurrent()) return false;
      if (current.level == 'FREE' &&
          current.benefits == null &&
          current.entitlementVersionId == null &&
          loadCatalog != null) {
        final catalog = await loadCatalog();
        if (!context.mounted || !isCurrent()) return false;
        // An unpublished catalog keeps legacy model-level admission.
        if (catalog.configVersionId == 0) return true;
      }
      final rights = current.benefits?['cloneEntitlements'];
      if (rights is! Map || rights['enabled'] is! bool) {
        throw const FormatException('Missing current clone entitlement');
      }
      if (rights['enabled'] == true) return true;
      currentMembership = '${membershipName(current.level)}会员';
      if (loadCatalog != null) {
        try {
          final catalog = await loadCatalog();
          if (!context.mounted || !isCurrent()) return false;
          final currentRank = membershipLevels.indexOf(current.level);
          if (catalog.configVersionId > 0 && currentRank >= 0) {
            supportedLevels = membershipLevels
                .skip(currentRank + 1)
                .where((level) {
                  final clone =
                      catalog.benefitsByLevel[level]?['cloneEntitlements'];
                  return clone is Map && clone['enabled'] == true;
                })
                .map((level) => '${membershipName(level)}会员')
                .join('或');
          }
        } catch (_) {
          // Optional catalog copy cannot change a known current denial.
        }
      }
    } catch (_) {
      if (!context.mounted || !isCurrent()) return false;
      final retry = await showDialog<bool>(
        context: context,
        builder: (_) => const NativeConfirmationDialog(
          title: '声音克隆权益读取失败',
          message: '暂时无法读取当前会员权益，请重试。',
          dismissLabel: '取消',
          confirmLabel: '重试',
        ),
      );
      if (retry == true) continue;
      return false;
    }
    if (!context.mounted || !isCurrent()) return false;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (_) => CloneEntitlementDialog(
        currentMembership: currentMembership,
        supportedLevels: supportedLevels,
      ),
    );
    if (!context.mounted || !isCurrent() || accepted != true) return false;
    await upgrade();
  }
  return false;
}
