import 'package:flutter/material.dart';

/// Shared native developer section spacing and translucent card.
class NativeDeveloperSection extends StatelessWidget {
  const NativeDeveloperSection({
    super.key,
    required this.title,
    required this.child,
    this.card = true,
    this.padding = const EdgeInsets.all(16),
  });
  final String title;
  final Widget child;
  final bool card;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (title.isNotEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 14, 4, 10),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111111),
            ),
          ),
        ),
      if (card)
        Container(
          padding: padding,
          decoration: BoxDecoration(
            color: const Color(0xCCFFFFFF),
            border: Border.all(color: const Color(0xC7FFFFFF)),
            borderRadius: BorderRadius.circular(24),
          ),
          child: DefaultTextStyle.merge(
            style: const TextStyle(
              fontSize: 13,
              height: 18 / 13,
              color: Color(0xFF6E6E73),
            ),
            child: child,
          ),
        )
      else
        child,
    ],
  );
}

class NativeDeveloperChoices extends StatelessWidget {
  const NativeDeveloperChoices({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (index, child) in children.indexed) ...[
          if (index > 0) const SizedBox(width: 10),
          Expanded(child: child),
        ],
      ],
    ),
  );
}
