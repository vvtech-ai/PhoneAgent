import 'package:flutter/material.dart';
import '../domain/feedback.dart';

class FeedbackImages extends StatelessWidget {
  const FeedbackImages({
    super.key,
    required this.images,
    required this.busy,
    required this.onAdd,
    required this.onRemove,
  });
  final List<FeedbackImage> images;
  final bool busy;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      if (images.isNotEmpty) ...[
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: images.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemBuilder: (context, i) => Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Material(
                    color: const Color(0xFFEEEEEE),
                    child: InkWell(
                      onTap: () => showDialog<void>(
                        context: context,
                        builder: (context) => Dialog(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: IconButton(
                                    tooltip: '关闭图片预览',
                                    onPressed: () => Navigator.pop(context),
                                    icon: const Icon(Icons.close),
                                  ),
                                ),
                                Flexible(
                                  child: InteractiveViewer(
                                    child: Image.memory(
                                      images[i].bytes,
                                      fit: BoxFit.contain,
                                      semanticLabel: '反馈图片预览',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      child: Image.memory(
                        images[i].bytes,
                        fit: BoxFit.cover,
                        cacheWidth: 320,
                        semanticLabel: '预览图片 ${i + 1}',
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: -7,
                right: -4,
                child: IconButton.filled(
                  constraints: const BoxConstraints.tightFor(
                    width: 32,
                    height: 32,
                  ),
                  padding: EdgeInsets.zero,
                  tooltip: '删除图片 ${i + 1}',
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFF44414E),
                  ),
                  onPressed: busy ? null : () => onRemove(i),
                  icon: const Icon(Icons.close, size: 20),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
      ],
      SizedBox(
        width: double.infinity,
        height: 60,
        child: CustomPaint(
          foregroundPainter: const _DashedOutline(),
          child: OutlinedButton.icon(
            key: const Key('feedback-add-images'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF666277),
              backgroundColor: const Color(0xFFFAFAFD),
              side: BorderSide.none,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: busy || images.length >= 6 ? null : onAdd,
            icon: const Icon(Icons.add),
            label: const Text('添加图片'),
          ),
        ),
      ),
    ],
  );
}

class _DashedOutline extends CustomPainter {
  const _DashedOutline();
  @override
  void paint(Canvas canvas, Size size) {
    final outline = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(12)),
      );
    final paint = Paint()
      ..color = const Color(0xFFBCBCC7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final metric in outline.computeMetrics()) {
      for (var offset = 0.0; offset < metric.length; offset += 8) {
        canvas.drawPath(metric.extractPath(offset, offset + 4), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedOutline oldDelegate) => false;
}
