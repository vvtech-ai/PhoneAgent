import 'package:flutter/material.dart';
import '../../../../core/design/ocr_tokens.dart';
import '../../domain/ocr_attachment.dart';
import '../../../conversation/presentation/widgets/native_thinking_card.dart';
import '../../../conversation/presentation/widgets/native_error_bubble.dart';

class OcrAttachmentCard extends StatefulWidget {
  const OcrAttachmentCard({
    super.key,
    required this.attachment,
    required this.image,
  });
  final OcrAttachment attachment;
  final ImageProvider image;
  @override
  State<OcrAttachmentCard> createState() => _OcrAttachmentCardState();
}

class _OcrAttachmentCardState extends State<OcrAttachmentCard> {
  bool _expanded = false;
  @override
  void didUpdateWidget(covariant OcrAttachmentCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.attachment.id != oldWidget.attachment.id) _expanded = false;
  }

  Widget _image(double? width, double? height) => ClipRRect(
    borderRadius: BorderRadius.circular(OcrTokens.imageRadius),
    child: Image(
      image: widget.image,
      width: width,
      height: height,
      fit: BoxFit.cover,
      semanticLabel: '所选图片',
      errorBuilder: (_, __, ___) =>
          const SizedBox(height: 60, child: Center(child: Text('图片暂不可用'))),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final item = widget.attachment, content = widget.attachment.content;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              width: OcrTokens.imageWidth,
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: OcrTokens.bubble,
                borderRadius: BorderRadius.circular(OcrTokens.radius),
              ),
              child: AspectRatio(aspectRatio: 4 / 3, child: _image(null, null)),
            ),
          ),
          if (item.status == OcrStatus.processing)
            const NativeThinkingCard(steps: ['AI 思考中']),
          if (item.status == OcrStatus.failed)
            NativeErrorBubble(message: item.failureMessage),
          if (item.status == OcrStatus.success && content != null)
            Container(
              constraints: const BoxConstraints(maxWidth: OcrTokens.cardWidth),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: OcrTokens.border),
                borderRadius: BorderRadius.circular(OcrTokens.radius),
                boxShadow: const [OcrTokens.shadow],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _image(OcrTokens.thumb, OcrTokens.thumb),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('已识别图片文字', style: OcrTokens.title),
                            const SizedBox(height: 4),
                            Text(content.summary, style: OcrTokens.summary),
                          ],
                        ),
                      ),
                    ],
                  ),
                  for (var index = 0; index < content.fields.length; index++)
                    Padding(
                      padding: EdgeInsets.only(top: index == 0 ? 12 : 8),
                      child: _field(content.fields[index]),
                    ),
                  const SizedBox(height: 12),
                  const Text('图中完整文字信息', style: OcrTokens.label),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: OcrTokens.field,
                      borderRadius: BorderRadius.circular(
                        OcrTokens.fieldRadius,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          content.displayText(_expanded),
                          style: OcrTokens.body,
                        ),
                        if (content.collapsible)
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () =>
                                  setState(() => _expanded = !_expanded),
                              child: Text(
                                _expanded ? '收起' : '展开',
                                style: const TextStyle(
                                  color: OcrTokens.accent,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _field(OcrField field) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: OcrTokens.field,
      borderRadius: BorderRadius.circular(OcrTokens.fieldRadius),
    ),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final label = Text(field.label, style: OcrTokens.label);
        final value = Text(field.value, style: OcrTokens.value);
        if (MediaQuery.textScalerOf(context).scale(13) > 19.5 ||
            constraints.maxWidth < 180) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [label, const SizedBox(height: 4), value],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 54, maxWidth: 86),
              child: label,
            ),
            Expanded(child: value),
          ],
        );
      },
    ),
  );
}
