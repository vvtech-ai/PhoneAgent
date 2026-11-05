import 'package:flutter/material.dart';

/// Effective native initials: 42 list / 88 profile, vertical gradient.
class ContactAvatar extends StatelessWidget {
  const ContactAvatar({super.key, required this.name, this.large = false});
  final String name;
  final bool large;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Container(
      width: large ? 88 : 42,
      height: large ? 88 : 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: large
            ? const [
                BoxShadow(
                  color: Color(0x384F7DFF),
                  blurRadius: 16,
                  offset: Offset(0, 6),
                ),
              ]
            : const [],
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF7AA8FF), Color(0xFF4F7DFF)],
        ),
      ),
      child: Text(
        name.trim().isEmpty ? '?' : name.trim().characters.first,
        style: TextStyle(
          fontSize: large ? 30 : 15,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    ),
  );
}
