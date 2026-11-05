import 'package:flutter/material.dart';

class TaskSyncSurface extends StatelessWidget {
  const TaskSyncSurface({super.key, required this.error, this.onRetry});
  final bool error;
  final VoidCallback? onRetry;
  void _retry(BuildContext context) {
    if (context.mounted && ModalRoute.of(context)?.isCurrent != false) {
      onRetry?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = error ? '同步失败，点击重试' : '正在同步...';
    final detail = error ? '部分任务同步失败（保留上次数据）' : '任务列表会自动更新';
    return Semantics(
      container: true,
      button: error,
      enabled: error ? onRetry != null : null,
      label: '$title，$detail',
      onTap: onRetry == null ? null : () => _retry(context),
      excludeSemantics: true,
      child: Material(
        color: error ? const Color(0xFFFFF1F2) : const Color(0xFFEFF6FF),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: error ? const Color(0xFFFECACA) : const Color(0xFFBFDBFE),
          ),
        ),
        child: InkWell(
          onTap: onRetry == null ? null : () => _retry(context),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    letterSpacing: .5,
                    height: 18 / 13,
                    fontWeight: FontWeight.w700,
                    color: error
                        ? const Color(0xFFB91C1C)
                        : const Color(0xFF1D4ED8),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: TextStyle(
                    fontSize: 12,
                    letterSpacing: .5,
                    height: 17 / 12,
                    color: error
                        ? const Color(0xFF991B1B)
                        : const Color(0xFF2563EB),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class TaskInitialLoading extends StatelessWidget {
  const TaskInitialLoading({super.key});
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox.square(
          dimension: 28,
          child: CircularProgressIndicator(
            value: MediaQuery.disableAnimationsOf(context) ? .65 : null,
            color: const Color(0xFF2478F2),
            strokeWidth: 2.5,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          '正在加载任务',
          style: TextStyle(
            fontSize: 14,
            height: 20 / 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF667085),
          ),
        ),
      ],
    ),
  );
}
