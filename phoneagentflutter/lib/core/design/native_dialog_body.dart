import 'package:flutter/material.dart';

/// Measures the whole body with the same typography and constraints as its text.
/// Custom text/link groups receive the resulting paragraph alignment explicitly.
class NativeDialogBody extends StatelessWidget {
  const NativeDialogBody(this.data, {super.key, this.style, this.builder});

  final String data;
  final TextStyle? style;
  final Widget Function(BuildContext, TextAlign)? builder;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      var effectiveStyle = DefaultTextStyle.of(context).style.merge(style);
      if (MediaQuery.boldTextOf(context)) {
        effectiveStyle = effectiveStyle.merge(
          const TextStyle(fontWeight: FontWeight.bold),
        );
      }
      final painter = TextPainter(
        text: TextSpan(text: data, style: effectiveStyle),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        locale: Localizations.maybeLocaleOf(context),
      )..layout(maxWidth: constraints.maxWidth);
      final alignment = painter.computeLineMetrics().length > 1
          ? TextAlign.left
          : TextAlign.center;
      painter.dispose();
      if (builder != null) {
        return DefaultTextStyle.merge(
          style: effectiveStyle,
          textAlign: alignment,
          child: builder!(context, alignment),
        );
      }
      return Text(data, textAlign: alignment, style: effectiveStyle);
    },
  );
}
