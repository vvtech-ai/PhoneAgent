import 'package:flutter/material.dart';
import '../../domain/translation_call_view.dart';

/// Owns only display scrolling; session accumulation stays in the controller.
class TranslationTranscriptThread extends StatefulWidget {
  const TranslationTranscriptThread({
    super.key,
    required this.transcripts,
    this.header,
  });
  final List<TranslationTranscript> transcripts;
  final Widget? header;
  @override
  State<TranslationTranscriptThread> createState() => _ThreadState();
}

class _ThreadState extends State<TranslationTranscriptThread> {
  final _scroll = ScrollController();
  String _latestKey(List<TranslationTranscript> items) {
    if (items.isEmpty) return '';
    final latest = items.last;
    return [
      latest.id,
      latest.source,
      latest.translated,
      '${latest.isFinal}',
    ].join('\u0000');
  }

  @override
  void didUpdateWidget(TranslationTranscriptThread oldWidget) {
    super.didUpdateWidget(oldWidget);
    final key = _latestKey(widget.transcripts);
    if (key.isNotEmpty && key != _latestKey(oldWidget.transcripts)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scroll.hasClients) _scroll.jumpTo(0);
      });
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ListView.separated(
      controller: _scroll,
      reverse: true,
      shrinkWrap: true,
      itemCount: widget.transcripts.length + (widget.header == null ? 0 : 1),
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => i == widget.transcripts.length
          ? widget.header!
          : TranslationTranscriptBubble(
              widget.transcripts[widget.transcripts.length - 1 - i],
            ),
    ),
  );
}

class TranslationTranscriptBubble extends StatelessWidget {
  const TranslationTranscriptBubble(this.item, {super.key});
  final TranslationTranscript item;
  @override
  Widget build(BuildContext context) => Align(
    alignment: item.mine ? Alignment.centerRight : Alignment.centerLeft,
    child: FractionallySizedBox(
      widthFactor: .82,
      child: Container(
        key: ValueKey(item.key),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: item.mine ? const Color(0xFF0A75DD) : const Color(0xF0FFFFFF),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.primary,
              style: TextStyle(
                color: item.mine ? Colors.white : const Color(0xFF111111),
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (item.secondary != null) ...[
              const SizedBox(height: 6),
              Text(
                item.secondary!,
                style: TextStyle(
                  fontSize: 12,
                  color: item.mine
                      ? const Color(0xB3FFFFFF)
                      : const Color(0xB3111111),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
