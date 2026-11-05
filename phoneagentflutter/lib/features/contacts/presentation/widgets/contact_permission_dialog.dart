import '../../../../core/design/native_business_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../controller/contact_tab_entry_coordinator.dart';

Future<bool> showContactPermissionDialog(
  BuildContext context,
  ContactPermissionDialogKind kind,
) async {
  final ios = Theme.of(context).platform == TargetPlatform.iOS;
  final blockingConsent = !ios && kind == ContactPermissionDialogKind.consent;
  if (ios || blockingConsent) {
    return await showGeneralDialog<bool>(
          context: context,
          barrierDismissible: ios,
          barrierLabel: '关闭通讯录权限说明',
          barrierColor: const Color(0x80000000),
          transitionDuration: Duration(milliseconds: ios ? 300 : 0),
          transitionBuilder: (_, animation, __, child) =>
              FadeTransition(opacity: animation, child: child),
          pageBuilder: (_, __, ___) => ios
              ? AnnotatedRegion<SystemUiOverlayStyle>(
                  value: SystemUiOverlayStyle.light,
                  child: ContactPermissionDialog(kind: kind),
                )
              : ContactPermissionDialog(kind: kind),
        ) ??
        false;
  }
  return await showDialog<bool>(
        context: context,
        useSafeArea: true,
        barrierDismissible: true,
        barrierLabel: '关闭通讯录权限说明',
        barrierColor: const Color(0x61000000),
        builder: (_) => ContactPermissionDialog(kind: kind),
      ) ??
      false;
}

class ContactPermissionDialog extends StatelessWidget {
  const ContactPermissionDialog({super.key, required this.kind});
  final ContactPermissionDialogKind kind;

  @override
  Widget build(BuildContext context) {
    final settings = kind == ContactPermissionDialogKind.settings;
    return NativeBusinessDialog(
      key: const ValueKey('contacts-permission-dialog'),
      surfaceKey: const ValueKey('contacts-permission-card'),
      title: settings ? '开启通讯录权限' : '允许访问通讯录？',
      message: settings ? '系统已关闭通讯录授权，请前往应用设置开启“通讯录”权限后继续。' : '用于选择联系人并发起通话任务',
      dismissLabel: settings ? '取消' : '暂不',
      confirmLabel: settings ? '去设置' : '继续授权',
      dismissKey: const ValueKey('contacts-permission-cancel'),
      confirmKey: const ValueKey('contacts-permission-confirm'),
      onDismiss: () => Navigator.pop(context, false),
      onConfirm: () => Navigator.pop(context, true),
    );
  }
}
