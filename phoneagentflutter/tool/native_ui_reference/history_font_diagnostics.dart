import 'package:flutter/material.dart';

/// Synthetic fixture metrics only; never used by the production application.
void printHistoryFontDiagnostics(BuildContext context) {
  final ambient = Theme.of(context).textTheme.bodyMedium!;
  for (final family in <String?>[
    null,
    'CupertinoSystemText',
    'CupertinoSystemDisplay',
  ]) {
    for (final sample in [
      ('合成翻译对象', 28.0, FontWeight.w700),
      ('+12025550123', 15.0, FontWeight.w400),
      ('请确认今天的营业时间。', 16.0, FontWeight.w400),
      ('Please confirm today’s opening hours.', 14.0, FontWeight.w400),
    ]) {
      final style = ambient.copyWith(
        fontFamily: family ?? ambient.fontFamily,
        fontSize: sample.$2,
        fontWeight: sample.$3,
        letterSpacing: 0,
      );
      final painter = TextPainter(
        text: TextSpan(text: sample.$1, style: style),
        textDirection: TextDirection.ltr,
      )..layout();
      debugPrint(
        'SYNTHETIC_HISTORY_FONT family=${style.fontFamily} '
        'size=${sample.$2} width=${painter.width} text=${sample.$1}',
      );
      painter.dispose();
    }
  }
}
