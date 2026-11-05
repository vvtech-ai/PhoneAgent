import 'package:flutter/material.dart';
import '../../domain/call_model_quality.dart';

/// Node response quality only; never a call readiness or billing signal.
class CallModelLatencyPill extends StatelessWidget {
  const CallModelLatencyPill({super.key, required this.sample});

  final CallModelReading? sample;

  @override
  Widget build(BuildContext context) {
    final reading = sample;
    final unavailable = reading?.confirmedUnavailable == true;
    final unknown =
        reading == null || reading.latencyMs == null && !unavailable;
    final measured = unknown ? null : reading.quality;
    final quality = switch (measured) {
      CallModelQuality.good => '良好',
      CallModelQuality.fair => '一般',
      CallModelQuality.high => '较高',
      CallModelQuality.unavailable || null => '',
    };
    final color = switch (measured) {
      CallModelQuality.good => const Color(0xFF34C759),
      CallModelQuality.fair => const Color(0xFFFFCC00),
      CallModelQuality.high => const Color(0xFFFF9500),
      CallModelQuality.unavailable => const Color(0xFFFF3B30),
      null => const Color(0xFFD1D5DB),
    };
    final label = unknown
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
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(100),
          ),
          child: Text(
            unknown
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
    );
  }
}
