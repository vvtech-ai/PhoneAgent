import 'package:flutter/material.dart';
import '../../../../core/design/native_business_dialog.dart';
import 'native_update_actions.dart';

/// Shared Android OTA offer and installation surface.
class NativeUpdateDialog extends StatelessWidget {
  const NativeUpdateDialog({
    super.key,
    required this.title,
    required this.version,
    required this.notes,
    required this.primary,
    required this.onPrimary,
    required this.primaryKey,
    this.onLater,
    this.later = '稍后',
    this.laterKey,
    this.force = false,
    this.status,
    this.error = '',
    this.extra,
  });
  final String title, version, notes, primary, later, error;
  final Key primaryKey;
  final Key? laterKey;
  final VoidCallback? onPrimary, onLater;
  final bool force;
  final Widget? status, extra;

  @override
  Widget build(BuildContext context) => NativeBusinessDialog(
    title: title,
    confirmLabel: primary,
    confirmKey: primaryKey,
    onConfirm: onPrimary,
    dismissLabel: later,
    dismissKey: laterKey,
    showDismiss: !force,
    onDismiss: onLater,
    actions: NativeUpdateActions(
      primary: primary,
      primaryKey: primaryKey,
      onPrimary: onPrimary,
      later: later,
      laterKey: laterKey,
      onLater: onLater,
      force: force,
    ),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '新版本：$version',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF344054),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          notes.trim().isEmpty ? '本次更新包含体验优化与问题修复。' : notes,
          textAlign: TextAlign.left,
          style: const TextStyle(fontSize: 14, height: 20 / 14),
        ),
        if (force) ...[
          const SizedBox(height: 10),
          const Text(
            '该版本为强制更新，更新完成前不可继续使用当前版本。',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Color(0xFFE14D46)),
          ),
        ],
        if (status != null) ...[const SizedBox(height: 10), status!],
        if (error.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            error,
            key: const Key('update-install-error'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: Color(0xFFE14D46)),
          ),
        ],
        if (extra != null) extra!,
      ],
    ),
  );
}
