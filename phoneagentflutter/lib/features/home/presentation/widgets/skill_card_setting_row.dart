import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../domain/home_config.dart';

class SkillCardSettingRow extends StatelessWidget {
  const SkillCardSettingRow({
    super.key,
    required this.card,
    required this.index,
    required this.visible,
    required this.enabled,
    required this.onVisible,
  });
  final HomeCard card;
  final int index;
  final bool visible, enabled;
  final ValueChanged<bool> onVisible;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    child: Column(
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                ReorderableDragStartListener(
                  index: index,
                  enabled: enabled,
                  child: Semantics(
                    label: '拖动${card.title}排序',
                    button: true,
                    child: SizedBox(
                      key: ValueKey('skill-drag-${card.id}'),
                      width: 32,
                      height: 32,
                      child: CustomPaint(painter: _SixDots()),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        card.title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      if (card.status == HomeCardStatus.comingSoon)
                        const Text(
                          '即将提供',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF98A2B3),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                CupertinoSwitch(
                  key: ValueKey('skill-visible-${card.id}'),
                  value: visible,
                  activeTrackColor: const Color(0xFF34C759),
                  onChanged: enabled ? onVisible : null,
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 1, thickness: 1, color: Color(0xFFF1F2F4)),
      ],
    ),
  );
}

class _SixDots extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFF98A2B3);
    for (final x in [.4, .6]) {
      for (final y in [.34, .5, .66]) {
        canvas.drawCircle(Offset(size.width * x, size.height * y), 1.2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
