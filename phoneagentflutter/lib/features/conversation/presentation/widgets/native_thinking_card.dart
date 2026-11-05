import 'package:flutter/material.dart';
import 'native_thinking_sparkles.dart';

/// Display-only native thinking state; no request or lifecycle ownership.
class NativeThinkingCard extends StatefulWidget {
  const NativeThinkingCard({
    super.key,
    required this.steps,
    this.title = 'Phone Agent',
    this.processing = true,
    this.sectionTitle = 'AI 思考过程',
  });
  final List<String> steps;
  final String title;
  final bool processing;
  final String sectionTitle;

  @override
  State<NativeThinkingCard> createState() => _NativeThinkingCardState();
}

class _NativeThinkingCardState extends State<NativeThinkingCard> {
  final _scroll = ScrollController();
  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Container(
      constraints: const BoxConstraints(maxWidth: 270),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF3F8FF), Color(0xFFEDF4FF)],
        ),
        border: Border.all(color: const Color(0x2E007AFF)),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(18),
          topRight: Radius.circular(18),
          bottomRight: Radius.circular(18),
          bottomLeft: Radius.circular(4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.processing)
            const NativeThinkingSparkles()
          else
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: Color(0xFF0A84FF),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    widget.title.trim().isEmpty ? 'Phone Agent' : widget.title,
                    style: const TextStyle(
                      color: Color(0xFF5F9FFF),
                      fontSize: 11,
                      height: 14 / 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 5),
          Text(
            widget.sectionTitle,
            style: const TextStyle(
              fontSize: 12,
              height: 16 / 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF50627D),
            ),
          ),
          if (widget.steps.any((text) => text.trim().isNotEmpty)) ...[
            const SizedBox(height: 4),
            LayoutBuilder(
              builder: (context, constraints) {
                final text = widget.steps
                    .where((s) => s.trim().isNotEmpty)
                    .map((s) => '· $s')
                    .join('\n');
                final style = DefaultTextStyle.of(context).style.merge(
                  const TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: Color(0xFF677892),
                  ),
                );
                final painter = TextPainter(
                  text: TextSpan(text: text, style: style),
                  textDirection: Directionality.of(context),
                  textScaler: MediaQuery.textScalerOf(context),
                  locale: Localizations.maybeLocaleOf(context),
                )..layout(maxWidth: constraints.maxWidth);
                final lines = painter.computeLineMetrics();
                final height = lines
                    .skip((lines.length - 3).clamp(0, lines.length))
                    .fold<double>(0, (sum, line) => sum + line.height);
                painter.dispose();
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && _scroll.hasClients) {
                    _scroll.jumpTo(_scroll.position.maxScrollExtent);
                  }
                });
                return ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: height),
                  child: SingleChildScrollView(
                    key: const ValueKey('thinking-lines'),
                    controller: _scroll,
                    child: Text(text, style: style),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    ),
  );
}
