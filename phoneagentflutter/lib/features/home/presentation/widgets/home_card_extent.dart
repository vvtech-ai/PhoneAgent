import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/design/shell_tokens.dart';
import '../../domain/home_config.dart';

/// C09 content height, including two-line titles/descriptions at large fonts.
double homeCardExtent(
  BuildContext context, {
  required double gridWidth,
  required Iterable<HomeCard> cards,
}) {
  // Two columns, a 12dp gap, 16dp inner padding and a 1dp border on each side.
  final contentWidth = math.max(1.0, (gridWidth - 12) / 2 - 34);
  final inherited = DefaultTextStyle.of(context).style;
  double measure(String text, TextStyle style, {int lines = 2}) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: inherited.merge(style)),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: lines,
      ellipsis: '…',
    )..layout(maxWidth: contentWidth);
    final height = painter.height;
    painter.dispose();
    return height;
  }

  final statusHeight = math.max(
    7.0,
    measure('请升级客户端', const TextStyle(fontSize: 10), lines: 1),
  );
  var height = 126.0;
  for (final card in cards) {
    height = math.max(
      height,
      34 +
          statusHeight +
          14 +
          measure(card.title, ShellTokens.cardTitle) +
          6 +
          measure(card.subtitle, ShellTokens.cardSubtitle),
    );
  }
  return height.ceilToDouble();
}
