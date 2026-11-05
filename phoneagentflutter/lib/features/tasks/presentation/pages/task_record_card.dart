import 'package:flutter/material.dart';
import '../../../../core/design/shell_tokens.dart';
import 'native_task_icon.dart';

/// Shared native task card; the caller owns status and navigation semantics.
class TaskRecordCard extends StatelessWidget {
  const TaskRecordCard({
    super.key,
    required this.title,
    required this.detail,
    required this.status,
    required this.statusColor,
    required this.onTap,
    this.onLongPress,
    this.enabled = true,
    this.unread = false,
    this.pinned = false,
    this.preview = false,
  });

  final String title, detail, status;
  final Color statusColor;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool enabled, unread, pinned, preview;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    button: true,
    enabled: enabled,
    label: [
      title,
      status,
      detail,
      if (unread) '未读结果',
      if (pinned) '已置顶',
    ].where((text) => text.isNotEmpty).join('，'),
    onTap: enabled ? onTap : null,
    onLongPress: enabled ? onLongPress : null,
    excludeSemantics: true,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: preview ? const Color(0xFFF3F5F9) : const Color(0xCCFFFFFF),
        borderRadius: const BorderRadius.all(Radius.circular(24)),
        border: const Border.fromBorderSide(
          BorderSide(color: Color(0xC7FFFFFF)),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14101114),
            blurRadius: 10,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: enabled ? onTap : null,
          onLongPress: enabled ? onLongPress : null,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (unread) ...[
                            Container(
                              key: const ValueKey('task-unread-dot'),
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                color: Color(0xFFE5484D),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Flexible(
                            child: Text(
                              title,
                              maxLines:
                                  MediaQuery.textScalerOf(context).scale(16) >
                                      16
                                  ? 2
                                  : 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                letterSpacing: 0,
                                height: 20 / 16,
                                fontWeight: FontWeight.w700,
                                color: ShellTokens.ink,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        detail,
                        maxLines:
                            MediaQuery.textScalerOf(context).scale(13) > 13
                            ? 2
                            : 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          letterSpacing: 0,
                          height: 19 / 13,
                          color: ShellTokens.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (status.isNotEmpty)
                      Text(
                        status,
                        style: TextStyle(
                          fontSize: 12,
                          height: 16 / 12,
                          fontWeight: FontWeight.w800,
                          color: statusColor,
                        ),
                      ),
                    if (pinned) ...[
                      const SizedBox(height: 6),
                      const NativeTaskIcon(
                        NativeTaskGlyph.pinned,
                        key: ValueKey('task-pinned-icon'),
                        size: 18,
                        color: Color(0xFF667085),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
