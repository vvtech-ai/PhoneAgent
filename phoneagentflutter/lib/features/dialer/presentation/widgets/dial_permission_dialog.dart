import 'package:flutter/material.dart';
import '../../domain/dial_permission.dart';
import '../controller/dial_permission_controller.dart';
import '../../../../core/design/native_business_dialog.dart';

/// A navigator dialog also covers the pre-dial settings bottom sheet.
class DialPermissionDialog extends StatefulWidget {
  const DialPermissionDialog({super.key, required this.controller});
  final DialPermissionController controller;
  @override
  State<DialPermissionDialog> createState() => _DialPermissionDialogState();
}

class _DialPermissionDialogState extends State<DialPermissionDialog> {
  late final VoidCallback remove;
  late DialPermissionState state = widget.controller.snapshot;
  bool closing = false;
  @override
  void initState() {
    super.initState();
    remove = widget.controller.addListener((value) {
      state = value;
      if (!mounted) return;
      if (!value.hasDialog && value.stage != DialPermissionStage.settings) {
        if (closing) return;
        closing = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Navigator.of(context).removeRoute(ModalRoute.of(context)!);
          }
        });
      }
      setState(() {});
    }, fireImmediately: false);
  }

  @override
  void dispose() {
    remove();
    super.dispose();
  }

  Future<void> _confirmAndroid() async {
    if (closing) return;
    final controller = widget.controller;
    closing = true;
    // Dismiss the explanation before Android draws authorization or settings.
    Navigator.of(context).removeRoute(ModalRoute.of(context)!);
    await controller.confirm();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final settings = state.stage == DialPermissionStage.settings;
    final blocked = state.stage == DialPermissionStage.blocked;
    final failed = state.stage == DialPermissionStage.failed;
    return PopScope(
      canPop: closing,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) controller.cancel();
      },
      child: NativeBusinessDialog(
        allowBack: closing,
        dismissLabel: '暂不开启',
        title: (settings
            ? '从系统设置返回'
            : failed
            ? '权限检查未完成'
            : blocked
            ? '需要位置权限'
            : '开启位置权限'),
        message: (settings
            ? '在系统设置中修改后返回，重新检查权限。'
            : failed
            ? state.message
            : blocked
            ? '位置权限已被关闭。请前往系统设置开启；未开启时仅可使用普通电话。'
            : '开启位置权限，以确认所在地区适用的实时翻译模型和通话线路，并提供更稳定的通话服务。不开启时仅可使用普通通话。'),
        onDismiss: closing ? null : controller.cancel,
        onConfirm: closing
            ? null
            : settings
            ? controller.resume
            : failed
            ? controller.retry
            : controller.androidNativeParity
            ? _confirmAndroid
            : controller.confirm,
        confirmLabel: settings
            ? '已返回，重新检查'
            : failed
            ? '重试'
            : blocked
            ? '前往系统设置'
            : '开启位置权限',
      ),
    );
  }
}
