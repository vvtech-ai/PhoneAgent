import 'package:flutter/material.dart';

/// Read-only notice with the caller's size and a regular gray system font.
class AiContentNotice extends StatelessWidget {
  const AiContentNotice({super.key, required this.style});

  final TextStyle style;

  @override
  Widget build(BuildContext context) => Center(
    child: Text(
      '内容由AI生成',
      style: style.copyWith(
        color: const Color(0xFF999999),
        fontWeight: FontWeight.normal,
        fontStyle: FontStyle.normal,
      ),
      softWrap: true,
    ),
  );
}
