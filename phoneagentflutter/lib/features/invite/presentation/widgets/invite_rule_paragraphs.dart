import 'package:flutter/material.dart';

final _number = RegExp(r'^\s*\d+[.、．)）]\s*');

/// Native paragraph boundaries only; keeps campaign wording and item numbers.
List<String> inviteRuleParagraphs(String text) {
  final result = <String>[];
  var paragraph = '';
  void flush() {
    if (paragraph.isNotEmpty) result.add(paragraph);
    paragraph = '';
  }

  for (final line in text.split(RegExp(r'\r\n|\n|\r'))) {
    if (line.trim().isEmpty) {
      flush();
      continue;
    }
    if (_number.hasMatch(line)) flush();
    paragraph = paragraph.isEmpty ? line : '$paragraph\n$line';
  }
  flush();
  return result;
}

class InviteRuleParagraphs extends StatelessWidget {
  const InviteRuleParagraphs({super.key, required this.text});
  final String text;
  static const _style = TextStyle(
    fontSize: 14,
    height: 1.5,
    color: Color(0xFF535D6A),
  );

  @override
  Widget build(BuildContext context) {
    final paragraphs = inviteRuleParagraphs(
      text.trim().isEmpty ? '活动规则暂不可用，请稍后刷新。' : text,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < paragraphs.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          _paragraph(paragraphs[i]),
        ],
      ],
    );
  }

  Widget _paragraph(String paragraph) {
    final prefix = _number.firstMatch(paragraph)?.group(0) ?? '';
    return Semantics(
      label: paragraph,
      excludeSemantics: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (prefix.isNotEmpty) ...[
            Text(prefix.trimRight(), style: _style),
            const SizedBox(width: 4),
          ],
          Expanded(
            child: Text(paragraph.substring(prefix.length), style: _style),
          ),
        ],
      ),
    );
  }
}
