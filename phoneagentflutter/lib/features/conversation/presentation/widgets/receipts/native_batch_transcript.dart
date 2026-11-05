import 'package:flutter/material.dart';
import '../../../domain/receipts/call_dialogue.dart';

/// Native batch transcript columns; single-call presentation stays independent.
class NativeBatchTranscript extends StatelessWidget {
  const NativeBatchTranscript({super.key, required this.lines});
  final List<CallDialogueLine> lines;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 5, bottom: 6),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (index, line) in lines.indexed) ...[
          if (index > 0) const SizedBox(height: 11),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 60,
                child: Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Text(
                    line.role == CallDialogueRole.assistant ? 'AI' : '对方',
                    style: TextStyle(
                      fontSize: 11,
                      height: 16 / 11,
                      fontWeight: FontWeight.w800,
                      color: line.role == CallDialogueRole.assistant
                          ? const Color(0xFF0877D1)
                          : const Color(0xFF218242),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Semantics(
                  container: true,
                  child: SelectableText(
                    line.text,
                    semanticsLabel: line.text,
                    strutStyle: StrutStyle.disabled,
                    textHeightBehavior: const TextHeightBehavior(
                      applyHeightToFirstAscent: false,
                      applyHeightToLastDescent: false,
                    ),
                    style: const TextStyle(
                      fontSize: 13,
                      height: 21 / 13,
                      color: Color(0xFF263142),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    ),
  );
}
