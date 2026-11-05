import 'package:flutter/material.dart';
import 'native_action_style.dart';
export 'native_action_style.dart' show NativeActionTone;

/// FinalActionButton / AISettingsGradientActionButton shared presentation.
class NativeGradientAction extends StatelessWidget {
  const NativeGradientAction({
    super.key,
    required this.label,
    required this.onPressed,
    this.tone = NativeActionTone.primary,
    this.actionKey,
    this.backgroundColor,
    this.foregroundColor,
  });
  final String label;
  final VoidCallback? onPressed;
  final NativeActionTone tone;
  final Key? actionKey;
  final Color? backgroundColor, foregroundColor;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return DecoratedBox(
      decoration: NativeActionStyle.decoration(
        enabled: enabled,
        tone: tone,
        backgroundColor: backgroundColor,
      ),
      child: TextButton(
        key: actionKey,
        onPressed: onPressed,
        style: NativeActionStyle.buttonStyle(
          context,
          tone: tone,
          foregroundColor: foregroundColor,
        ),
        child: Text(label, textAlign: TextAlign.center),
      ),
    );
  }
}
