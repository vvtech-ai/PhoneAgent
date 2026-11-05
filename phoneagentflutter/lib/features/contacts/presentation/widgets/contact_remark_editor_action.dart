import 'package:flutter/material.dart';
import '../../../../core/design/native_gradient_action.dart';

/// Separates the native visible button from its accessible touch area.
class ContactRemarkEditorAction extends StatelessWidget {
  const ContactRemarkEditorAction({
    super.key,
    required this.label,
    required this.enabled,
    required this.onPressed,
    this.filled = false,
  });

  final String label;
  final bool enabled;
  final VoidCallback onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return NativeGradientAction(
      label: label,
      tone: filled ? NativeActionTone.primary : NativeActionTone.secondary,
      onPressed: enabled ? onPressed : null,
    );
  }
}
