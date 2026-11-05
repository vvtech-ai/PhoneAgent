import 'package:flutter/material.dart';
import '../../domain/translation_model_quality.dart';

/// Node response quality only; never a call readiness or billing signal.
class TranslationLatencyPill extends StatelessWidget {
  const TranslationLatencyPill({super.key, required this.sample});

  final TranslationModelSample? sample;

  @override
  Widget build(BuildContext context) {
    final reading = sample;
    final unavailable = reading != null && reading.latencyMs == null;
    final quality = switch (reading?.quality) {
      TranslationQuality.good => '良好',
      TranslationQuality.fair => '一般',
      TranslationQuality.high => '较高',
      TranslationQuality.unavailable || null => '',
    };
    final color = switch (reading?.quality) {
      TranslationQuality.good => const Color(0xFF34C759),
      TranslationQuality.fair => const Color(0xFFFFCC00),
      TranslationQuality.high => const Color(0xFFFF9500),
      TranslationQuality.unavailable => const Color(0xFFFF3B30),
      null => const Color(0xFFD1D5DB),
    };
    final label = reading == null
        ? '模型延迟暂无数据'
        : unavailable
        ? '模型不可用'
        : '模型延迟$quality，${reading.latencyMs}毫秒';
    return Semantics(
      label: label,
      child: ExcludeSemantics(
        child: Container(
          constraints: BoxConstraints(
            minHeight: 16,
            minWidth: unavailable ? 44 : 38,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(100),
          ),
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: Text(
              reading == null
                  ? ''
                  : unavailable
                  ? '不可用'
                  : '${reading.latencyMs}ms',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                height: 1.2,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
