import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../domain/account_memory.dart';
import '../../domain/memory_skill_selection.dart';
import 'memory_frame.dart';

class MemoryOverview extends StatelessWidget {
  const MemoryOverview({
    super.key,
    required this.snapshot,
    required this.list,
    required this.busy,
    required this.onEnabled,
    required this.onList,
    required this.onAdd,
    required this.onEdit,
  });
  final MemorySnapshot snapshot;
  final bool list, busy;
  final ValueChanged<bool> onEnabled;
  final VoidCallback onList, onAdd;
  final ValueChanged<MemoryEntry> onEdit;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    children: list
        ? [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                '容量使用',
                style: TextStyle(fontSize: 13, color: MemoryColors.secondary),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 10, 4, 18),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(50),
                child: LinearProgressIndicator(
                  value: memoryCapacity(snapshot),
                  minHeight: 6,
                  color: MemoryColors.blue,
                  backgroundColor: const Color(0xFFE4E9F1),
                ),
              ),
            ),
            MemoryCard(
              child: snapshot.entries.isEmpty
                  ? const SizedBox(
                      height: 220,
                      child: Center(
                        child: Text(
                          '暂无记忆',
                          style: TextStyle(
                            fontSize: 15,
                            color: MemoryColors.secondary,
                          ),
                        ),
                      ),
                    )
                  : Column(
                      children: [
                        for (final indexed in snapshot.entries.indexed) ...[
                          if (indexed.$1 > 0)
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 22),
                              child: Divider(
                                height: 1,
                                color: MemoryColors.divider,
                              ),
                            ),
                          InkWell(
                            onTap: busy ? null : () => onEdit(indexed.$2),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(minHeight: 82),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 22,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        memoryPreview(indexed.$2.content),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          color: MemoryColors.text,
                                        ),
                                      ),
                                    ),
                                    const Padding(
                                      padding: EdgeInsets.only(left: 14),
                                      child: Icon(
                                        Icons.chevron_right,
                                        size: 20,
                                        color: MemoryColors.secondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
            const SizedBox(height: 18),
            Center(
              child: TextButton(
                onPressed: busy ? null : onAdd,
                child: const Text(
                  '＋ 添加记忆',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: MemoryColors.blue,
                  ),
                ),
              ),
            ),
          ]
        : [
            MemoryCard(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 18,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            '记忆',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w500,
                              color: MemoryColors.text,
                            ),
                          ),
                        ),
                        CupertinoSwitch(
                          value: snapshot.enabled,
                          activeTrackColor: const Color(0xFF34C759),
                          onChanged: busy ? null : onEnabled,
                        ),
                      ],
                    ),
                    const Text(
                      'AI 会在后续任务对话中提供个性化体验。',
                      style: TextStyle(
                        fontSize: 13,
                        height: 21 / 13,
                        color: MemoryColors.secondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            MemoryCard(
              child: InkWell(
                onTap: busy ? null : onList,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 76),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 22),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '记忆内容',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w500,
                              color: MemoryColors.text,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          size: 20,
                          color: MemoryColors.secondary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
  );
}
