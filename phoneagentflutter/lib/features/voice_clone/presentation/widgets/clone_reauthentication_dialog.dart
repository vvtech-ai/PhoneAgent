import '../../../../core/design/native_business_dialog.dart';
import 'package:flutter/material.dart';

/// Existing-clone confirmation retains its single-close business guard.
class CloneReauthenticationDialog extends StatefulWidget {
  const CloneReauthenticationDialog({super.key, required this.modelName});
  final String modelName;

  @override
  State<CloneReauthenticationDialog> createState() =>
      _CloneReauthenticationDialogState();
}

class _CloneReauthenticationDialogState
    extends State<CloneReauthenticationDialog> {
  bool _closing = false;

  void _close(bool confirmed) {
    if (!mounted || _closing || ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    _closing = true;
    Navigator.of(context).pop(confirmed);
  }

  @override
  Widget build(BuildContext context) => NativeBusinessDialog(
    title: '重新认证并克隆音色？',
    message: '${widget.modelName} 已有克隆音色。继续后需要重新完成身份认证和声音采集。',
    kind: NativeDialogKind.confirmation,
    dismissLabel: '取消',
    confirmLabel: '继续重新认证',
    dismissKey: const Key('clone-reauth-cancel'),
    confirmKey: const Key('clone-reauth-confirm'),
    onDismiss: () => _close(false),
    onConfirm: () => _close(true),
  );
}
