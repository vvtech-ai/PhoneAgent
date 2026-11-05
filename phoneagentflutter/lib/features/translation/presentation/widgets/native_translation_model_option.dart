import 'package:flutter/material.dart';
import '../../domain/translation_model_quality.dart';
import 'translation_latency_pill.dart';

/// Common native card geometry; admission and quality remain caller-owned.
class NativeTranslationModelOption extends StatelessWidget {
  const NativeTranslationModelOption({
    super.key,
    required this.name,
    required this.subtitle,
    required this.selected,
    required this.onSelect,
    this.multiplier,
    this.available,
    this.sample,
    this.recommended = false,
    this.showLatency = true,
  });
  final String name, subtitle;
  final bool? available;
  final bool selected, recommended, showLatency;
  final VoidCallback? onSelect;
  final double? multiplier;
  final TranslationModelSample? sample;

  @override
  Widget build(BuildContext context) {
    final enabled = available ?? onSelect != null;
    final ios = Theme.of(context).platform == TargetPlatform.iOS;
    final badgeScale = MediaQuery.textScalerOf(context).scale(11) / 11;
    final active = selected;
    final rate = multiplier;
    final billing = rate != null && rate.isFinite && rate > 0
        ? '×${rate.toStringAsFixed(1)}'
        : '';
    final accent = const Color(0xFF0A84FF);
    return Semantics(
      container: true,
      explicitChildNodes: true,
      button: true,
      selected: active,
      enabled: onSelect != null,
      label: '$name${billing.isEmpty ? '' : '，$billing'}，$subtitle',
      onTap: onSelect,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Material(
          color: active ? const Color(0xFFF8F7FF) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              width: 1.5,
              color: active ? accent : const Color(0xFFE5E7EB),
            ),
          ),
          child: InkWell(
            onTap: onSelect,
            excludeFromSemantics: true,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 7,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            ExcludeSemantics(
                              child: Text(
                                name,
                                style: TextStyle(
                                  fontSize: 15,
                                  height: 1.2,
                                  fontWeight: FontWeight.w600,
                                  color: enabled
                                      ? const Color(0xFF1A1A2E)
                                      : const Color(0xFF9B9BA1),
                                ),
                              ),
                            ),
                            if (billing.isNotEmpty)
                              ExcludeSemantics(
                                child: Text(
                                  billing,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF98A2B3),
                                  ),
                                ),
                              ),
                            if (showLatency)
                              TranslationLatencyPill(sample: sample),
                          ],
                        ),
                        const SizedBox(height: 2),
                        ExcludeSemantics(
                          child: Text(
                            subtitle,
                            maxLines: ios ? 1 : null,
                            overflow: ios ? TextOverflow.ellipsis : null,
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.2,
                              color: enabled
                                  ? const Color(0xFF8B8FA3)
                                  : const Color(0xFF9CA3AF),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (recommended && enabled) const SizedBox(width: 14),
                  if (recommended && enabled)
                    Container(
                      key: const ValueKey('translation-native-recommendation'),
                      constraints: ios
                          ? BoxConstraints.tightFor(
                              width: 38 * badgeScale,
                              height: 20 * badgeScale,
                            )
                          : null,
                      alignment: ios ? Alignment.center : null,
                      padding: ios
                          ? EdgeInsets.zero
                          : const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF3FF),
                        borderRadius: BorderRadius.circular(
                          ios ? 10 * badgeScale : 100,
                        ),
                      ),
                      child: const Text(
                        '推荐',
                        style: TextStyle(
                          fontSize: 11,
                          height: 14 / 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1677FF),
                        ),
                      ),
                    ),

                  const SizedBox(width: 14),
                  Container(
                    key: const ValueKey('translation-native-radio'),
                    width: 20,
                    height: 20,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        width: 1.5,
                        color: !enabled
                            ? const Color(0xFFCCD3DE)
                            : active
                            ? accent
                            : const Color(0xFF98A2B3),
                      ),
                    ),
                    child: active
                        ? Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: accent,
                              shape: BoxShape.circle,
                            ),
                          )
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
