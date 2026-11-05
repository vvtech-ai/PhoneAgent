import 'package:flutter/material.dart';
import '../controller/task_controller.dart';
import 'native_task_icon.dart';

class TaskPinnedHeader extends StatelessWidget {
  const TaskPinnedHeader({
    super.key,
    required this.collapsed,
    required this.count,
    required this.onToggle,
  });
  final bool collapsed;
  final int count;
  final VoidCallback onToggle;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onToggle,
    child: SizedBox(
      height: 44,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFEDF0F4),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                collapsed ? '$count 个置顶任务' : '收起置顶任务',
                style: const TextStyle(
                  fontSize: 12,
                  height: 20 / 12,
                  color: Color(0xFF596273),
                ),
              ),
              const SizedBox(width: 6),
              RotatedBox(
                quarterTurns: collapsed ? 0 : 2,
                child: const NativeTaskIcon(
                  NativeTaskGlyph.fold,
                  size: 14,
                  color: Color(0xFF596273),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class TaskPaginationFooter extends StatelessWidget {
  const TaskPaginationFooter({super.key, required this.state, this.onLoadMore});
  final TaskState state;
  final VoidCallback? onLoadMore;
  @override
  Widget build(BuildContext context) {
    final text = state.loadingMore
        ? '正在加载…'
        : state.moreFailed
        ? '加载失败，点击重试'
        : state.hasMore
        ? '继续上滑，加载更多任务'
        : '已显示全部任务';
    return TextButton(
      key: const ValueKey('tasks-load-more'),
      onPressed: state.hasMore && !state.loadingMore && !state.loading
          ? onLoadMore
          : null,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (state.loadingMore) ...[
            const SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Color(0xFF667085)),
            ),
          ),
        ],
      ),
    );
  }
}

class TaskClearUnreadButton extends StatelessWidget {
  const TaskClearUnreadButton({super.key, this.onPressed});
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => Semantics(
    label: '清空所有未读状态',
    button: true,
    enabled: onPressed != null,
    child: IconButton(
      constraints: const BoxConstraints.tightFor(width: 44, height: 44),
      padding: const EdgeInsets.all(10),
      onPressed: onPressed,
      icon: NativeTaskIcon(
        NativeTaskGlyph.clearUnread,
        color: onPressed != null
            ? const Color(0xFF596273)
            : const Color(0xFFC4C9D1),
      ),
    ),
  );
}
