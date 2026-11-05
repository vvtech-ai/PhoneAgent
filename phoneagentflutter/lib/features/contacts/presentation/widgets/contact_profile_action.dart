import 'package:flutter/material.dart';

class ContactProfileAction extends StatelessWidget {
  const ContactProfileAction({
    super.key,
    required this.label,
    required this.onTap,
    this.primary = false,
  });
  final String label;
  final VoidCallback? onTap;
  final bool primary;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: onTap != null,
    child: Opacity(
      opacity: onTap == null ? .38 : 1,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: primary
                ? const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF34C759), Color(0xFF28A745)],
                  )
                : null,
            color: primary ? null : const Color(0xD6FFFFFF),
            border: primary ? null : Border.all(color: const Color(0x143C3C43)),
          ),
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 50),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: primary ? Colors.white : const Color(0xFF111111),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
