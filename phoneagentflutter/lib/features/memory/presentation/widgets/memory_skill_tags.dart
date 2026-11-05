import 'package:flutter/material.dart';
import '../../domain/account_memory.dart';
import 'memory_frame.dart';

class MemorySkillTags extends StatelessWidget {
  const MemorySkillTags({
    super.key,
    required this.scope,
    required this.ids,
    required this.skills,
    required this.enabled,
    required this.onRemove,
    required this.onOpen,
  });
  final MemoryScope scope;
  final Set<String> ids;
  final List<MemorySkill> skills;
  final bool enabled;
  final ValueChanged<String?> onRemove;
  final VoidCallback onOpen;
  @override
  Widget build(BuildContext context) {
    final labelPainter = TextPainter(
      text: TextSpan(
        text: '＋ 添加',
        style: DefaultTextStyle.of(context).style.copyWith(fontSize: 14),
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      locale: Localizations.maybeLocaleOf(context),
      textHeightBehavior: DefaultTextStyle.of(context).textHeightBehavior,
      maxLines: 1,
    )..layout();
    final controlHeight = labelPainter.height + 20;
    labelPainter.dispose();
    final tags = [
      if (scope == MemoryScope.all) const MemorySkill('', '全部任务', true),
      for (final id in ids)
        skills.where((skill) => skill.id == id).firstOrNull ??
            MemorySkill(id, id, false),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4),
          child: Text(
            '适用任务',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: MemoryColors.text,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final tag in tags)
              Container(
                height: controlHeight,
                decoration: BoxDecoration(
                  color: tag.enabled
                      ? MemoryColors.lightBlue
                      : const Color(0xFFE9ECF1),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.only(left: 14),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        '${tag.name}${tag.enabled ? '' : ' · 已停用'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          color: tag.enabled
                              ? MemoryColors.blue
                              : MemoryColors.secondary,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: '移除${tag.name}标签',
                      padding: const EdgeInsets.all(11),
                      constraints: const BoxConstraints(),
                      onPressed: enabled
                          ? () => onRemove(tag.id.isEmpty ? null : tag.id)
                          : null,
                      icon: Icon(
                        Icons.close,
                        size: 14,
                        color: tag.enabled
                            ? MemoryColors.blue
                            : MemoryColors.secondary,
                      ),
                    ),
                  ],
                ),
              ),
            CustomPaint(
              painter: _DashedBorder(),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                key: const Key('memory-open-skills'),
                onTap: enabled ? onOpen : null,
                child: SizedBox(
                  height: controlHeight,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Center(
                      widthFactor: 1,
                      child: Text(
                        tags.isEmpty ? '选择适用任务' : '＋ 添加',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          color: MemoryColors.secondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        if (tags.isNotEmpty && tags.every((tag) => !tag.enabled))
          const Padding(
            padding: EdgeInsets.only(left: 4, top: 10),
            child: Text(
              '暂无可用的适用任务',
              style: TextStyle(fontSize: 12, color: MemoryColors.secondary),
            ),
          ),
      ],
    );
  }
}

class _DashedBorder extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(12)),
      );
    final paint = Paint()
      ..color = const Color(0xFFCBD2DC)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final metric in path.computeMetrics()) {
      for (double start = 0; start < metric.length; start += 7) {
        canvas.drawPath(
          metric.extractPath(start, (start + 4).clamp(0, metric.length)),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
