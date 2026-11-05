import 'package:flutter/material.dart';
import '../../domain/task_voice.dart';

class TaskVoiceChoiceRow extends StatelessWidget {
  const TaskVoiceChoiceRow({
    super.key,
    required this.voice,
    required this.selected,
    required this.previewing,
    required this.onSelect,
    required this.onPreview,
  });
  final TaskVoice voice;
  final bool selected, previewing;
  final VoidCallback? onSelect;
  final VoidCallback? onPreview;
  @override
  Widget build(BuildContext context) => Material(
    color: selected ? const Color(0xFFEDF7FF) : Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: BorderSide(
        color: selected ? const Color(0xFFBCDDF5) : const Color(0xFFE6E9EE),
      ),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      key: ValueKey('task-voice-${voice.speaker}'),
      onTap: onSelect,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    voice.displayName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    voice.description,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF8B919D),
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFDDEFFF),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Text(
                  '当前',
                  style: TextStyle(fontSize: 11, color: Color(0xFF0A84FF)),
                ),
              ),
            const SizedBox(width: 8),
            SizedBox(
              width: 32,
              height: 32,
              child: IconButton(
                tooltip: previewing ? '停止试听' : '试听${voice.displayName}',
                padding: EdgeInsets.zero,
                onPressed: onPreview,
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFFF2F7FF),
                ),
                icon: Icon(
                  previewing ? Icons.stop : Icons.play_arrow,
                  size: 18,
                  color: const Color(0xFF0A84FF),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
