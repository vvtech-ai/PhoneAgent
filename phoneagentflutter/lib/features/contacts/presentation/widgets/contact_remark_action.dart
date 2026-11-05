import 'package:flutter/material.dart';

/// Native visible geometry with a separate accessible interaction area.
class ContactRemarkAction extends StatelessWidget {
  const ContactRemarkAction({
    super.key,
    required this.label,
    required this.onTap,
    this.danger = false,
  });
  final String label;
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    button: true,
    enabled: onTap != null,
    label: label,
    onTap: onTap,
    excludeSemantics: true,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: 48,
            minWidth: danger ? 52 : 60,
          ),
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: Container(
              constraints: BoxConstraints(minWidth: danger ? 52 : 60),
              decoration: BoxDecoration(
                color: danger ? null : const Color(0x140A84FF),
                borderRadius: BorderRadius.circular(14),
              ),
              padding: EdgeInsets.symmetric(
                horizontal: danger ? 10 : 14,
                vertical: 8,
              ),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 20 / 14,
                  letterSpacing: 0,
                  fontWeight: FontWeight.w700,
                  color: onTap == null
                      ? const Color(0xFF8E8E93)
                      : danger
                      ? const Color(0xFFD62E29)
                      : const Color(0xFF0A84FF),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
