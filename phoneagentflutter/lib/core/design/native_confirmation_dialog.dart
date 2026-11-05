import 'package:flutter/material.dart';
import 'native_business_dialog.dart';

/// Boolean-result adapter; lifecycle remains owned by the initiating route.
class NativeConfirmationDialog extends StatelessWidget {
  const NativeConfirmationDialog({
    super.key,
    required this.title,
    required this.message,
    required this.confirmLabel,
    this.dismissLabel = '取消',
    this.danger = false,
    this.allowBack = true,
    this.confirmKey,
    this.dismissKey,
  });
  final String title, message, confirmLabel, dismissLabel;
  final bool danger, allowBack;
  final Key? confirmKey, dismissKey;
  @override
  Widget build(BuildContext context) => NativeBusinessDialog(
    title: title,
    message: message,
    confirmLabel: confirmLabel,
    dismissLabel: dismissLabel,
    danger: danger,
    allowBack: allowBack,
    confirmKey: confirmKey,
    dismissKey: dismissKey,
    kind: NativeDialogKind.confirmation,
    onConfirm: () => Navigator.pop(context, true),
    onDismiss: () => Navigator.pop(context, false),
  );
}
