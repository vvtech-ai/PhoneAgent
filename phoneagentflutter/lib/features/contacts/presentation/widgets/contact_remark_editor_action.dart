import 'package:flutter/material.dart';

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
    final foreground = filled
        ? Colors.white
        : enabled
        ? const Color(0xFF0A84FF)
        : const Color(0xFFA6A6A6);
    return TextButton(
      onPressed: enabled ? onPressed : null,
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: filled
              ? enabled
                    ? const Color(0xFF0A84FF)
                    : const Color(0xFFD6D6D6)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: filled ? 16 : 8,
            vertical: 8,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              height: 20 / 14,
              letterSpacing: 0,
              fontWeight: FontWeight.w500,
              color: foreground,
            ),
          ),
        ),
      ),
    );
  }
}
