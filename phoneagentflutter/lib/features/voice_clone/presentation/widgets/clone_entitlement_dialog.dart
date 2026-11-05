import 'package:flutter/material.dart';
import '../../../../core/design/native_business_dialog.dart';

class CloneEntitlementDialog extends StatelessWidget {
  const CloneEntitlementDialog({
    super.key,
    this.currentMembership,
    this.supportedLevels,
  });
  final String? currentMembership;
  final String? supportedLevels;

  @override
  Widget build(BuildContext context) => NativeBusinessDialog(
    title: '暂无声音克隆权益',
    message: supportedLevels?.isNotEmpty == true
        ? '当前${currentMembership ?? '会员'}暂不支持声音克隆。$supportedLevels支持该功能，可前往查看会员权益。'
        : '当前${currentMembership ?? '会员'}暂不支持声音克隆，可前往会员页查看各等级权益。',
    kind: NativeDialogKind.confirmation,
    dismissLabel: '取消',
    confirmLabel: '查看会员权益',
    dismissKey: const Key('clone-entitlement-cancel'),
    confirmKey: const Key('clone-entitlement-upgrade'),
    onDismiss: () => Navigator.pop(context, false),
    onConfirm: () => Navigator.pop(context, true),
  );
}
