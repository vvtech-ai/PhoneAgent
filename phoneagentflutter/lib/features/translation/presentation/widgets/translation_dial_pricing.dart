import 'package:flutter/material.dart';
import '../../domain/translation_directory.dart';
import '../../domain/translation_dial_pricing.dart';

class TranslationDialPricing extends StatelessWidget {
  const TranslationDialPricing({super.key, this.model});
  final TranslationDirectoryModel? model;

  @override
  Widget build(BuildContext context) => RichText(
    key: const Key('translation-dial-pricing'),
    textAlign: TextAlign.center,
    textScaler: MediaQuery.textScalerOf(context),
    text: TextSpan(
      style: const TextStyle(
        fontSize: 10,
        height: 1.4,
        color: Color(0xFF9297A1),
      ),
      children: [
        for (final (index, segment) in translationDialPricingText(
          model,
        ).split('✦').indexed) ...[
          if (index > 0)
            const TextSpan(
              text: '✦',
              style: TextStyle(color: Color(0xFFFFC400)),
            ),
          TextSpan(text: segment),
        ],
      ],
    ),
  );
}
