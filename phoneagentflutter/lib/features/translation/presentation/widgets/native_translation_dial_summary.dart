import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Shared model and language entry row above the dial pad.
class NativeTranslationDialSummary extends StatelessWidget {
  const NativeTranslationDialSummary({
    super.key,
    required this.model,
    required this.languages,
    required this.translationEnabled,
    required this.onModel,
    required this.onLanguages,
    this.multiplier,
  });
  final String model, languages;
  final bool translationEnabled;
  final VoidCallback? onModel, onLanguages;
  final double? multiplier;

  static const _modelStyle = TextStyle(
    color: Color(0xFF344054),
    fontSize: 13.5,
    height: 1.2,
    letterSpacing: 0,
    fontWeight: FontWeight.w600,
  );
  static const _rateStyle = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: Color(0xFF98A2B3),
  );

  @override
  Widget build(BuildContext context) {
    final languageLabel = translationEnabled ? languages : '实时翻译  关';
    final rate = multiplier;
    final rateLabel = rate != null && rate.isFinite && rate > 0
        ? '×$rate'
        : null;
    final languageStyle = _modelStyle.copyWith(
      color: translationEnabled
          ? const Color(0xFF30323A)
          : const Color(0xFF8E8E93),
    );
    double measure(String text, TextStyle style) {
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: DefaultTextStyle.of(context).style.merge(style),
        ),
        maxLines: 1,
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout();
      final width = painter.width;
      painter.dispose();
      return width;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final languageWidth = measure(languageLabel, languageStyle) + 17;
        final minimumModelWidth =
            7 +
            6 +
            17 +
            math.min(
              measure(model, _modelStyle),
              MediaQuery.textScalerOf(context).scale(48),
            ) +
            (rateLabel == null ? 0 : 5 + measure(rateLabel, _rateStyle));
        final stacked = languageWidth + minimumModelWidth + 8 > width;
        final modelEntry = _Entry(
          key: const ValueKey('translation-model-open'),
          maxWidth: width,
          label: '翻译模型：$model${rateLabel == null ? '' : '，$rateLabel'}',
          onTap: onModel,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: translationEnabled
                    ? const Color(0xFF6C5CE7)
                    : const Color(0xFFB7BAC2),
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                model,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _modelStyle,
              ),
            ),
            if (rateLabel != null)
              Padding(
                padding: const EdgeInsets.only(left: 5),
                child: Text(rateLabel, maxLines: 1, style: _rateStyle),
              ),
            const Icon(
              Icons.keyboard_arrow_down,
              size: 17,
              color: Color(0xFF667085),
            ),
          ],
        );
        final languageEntry = _Entry(
          key: const ValueKey('translation-presets-open'),
          maxWidth: math.min(width, languageWidth),
          label: '设置双方语言，$languageLabel',
          onTap: onLanguages,
          children: [
            Flexible(
              child: Text(
                languageLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: languageStyle,
              ),
            ),
            const Icon(
              Icons.keyboard_arrow_down,
              size: 17,
              color: Color(0xFF667085),
            ),
          ],
        );
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: stacked
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    modelEntry,
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: languageEntry,
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(child: modelEntry),
                    const SizedBox(width: 8),
                    languageEntry,
                  ],
                ),
        );
      },
    );
  }
}

class _Entry extends StatelessWidget {
  const _Entry({
    super.key,
    required this.maxWidth,
    required this.label,
    required this.onTap,
    required this.children,
  });
  final double maxWidth;
  final String label;
  final VoidCallback? onTap;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    button: true,
    enabled: onTap != null,
    label: label,
    onTap: onTap,
    child: ExcludeSemantics(
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: 18, maxWidth: maxWidth),
          child: Row(mainAxisSize: MainAxisSize.min, children: children),
        ),
      ),
    ),
  );
}
