import 'package:flutter/material.dart';

/// v67 InviteSingleLineText: keep amounts/counts complete on one line.
class InviteSingleLineText extends StatelessWidget {
  const InviteSingleLineText(
    this.text, {
    super.key,
    required this.style,
    this.alignment = Alignment.centerLeft,
  });
  final String text;
  final TextStyle style;
  final Alignment alignment;
  @override
  Widget build(BuildContext context) => Semantics(
    label: text,
    excludeSemantics: true,
    child: FittedBox(
      fit: BoxFit.scaleDown,
      alignment: alignment,
      child: Text(text, style: style, maxLines: 1, softWrap: false),
    ),
  );
}
