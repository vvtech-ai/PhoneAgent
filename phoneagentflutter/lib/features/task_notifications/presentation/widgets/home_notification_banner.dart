import 'package:flutter/material.dart';
import '../../../tasks/domain/task_records.dart';
import '../../domain/home_notification.dart';

/// Independent open and dismiss actions; no storage or network in presentation.
class HomeNotificationBanner extends StatelessWidget {
  const HomeNotificationBanner({
    super.key,
    this.item,
    this.pendingCount = 0,
    this.busy = false,
    this.notice = '',
    required this.onOpen,
    required this.onDismiss,
    required this.onRetry,
  });
  final HomeNotification? item;
  final int pendingCount;
  final bool busy;
  final String notice;
  final VoidCallback onOpen, onDismiss, onRetry;

  @override
  Widget build(BuildContext context) {
    final current = item;
    if (current == null && notice.isEmpty) return const SizedBox.shrink();
    final palette = switch (current?.status) {
      TaskStatus.incomplete => const [
        Color(0xFFFFF7ED),
        Color(0xFFFFDDB3),
        Color(0xFFF59E0B),
      ],
      TaskStatus.running => const [
        Color(0xFFEFF6FF),
        Color(0xFFBFDBFE),
        Color(0xFF3B82F6),
      ],
      TaskStatus.executionError => const [
        Color(0xFFFEF2F2),
        Color(0xFFFECACA),
        Color(0xFFEF4444),
      ],
      _ => const [Color(0xFFEBF5FF), Color(0xFFB3D7FF), Color(0xFF007AFF)],
    };
    final extra = pendingCount > 1 ? '还有 ${pendingCount - 1} 条' : '';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (current != null)
          Container(
            key: const ValueKey('home-task-notification'),
            decoration: BoxDecoration(
              color: palette[0],
              border: Border(bottom: BorderSide(color: palette[1])),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Semantics(
                    container: true,
                    button: true,
                    enabled: true,
                    label: '${current.text}${extra.isEmpty ? '' : '，$extra'}',
                    onTap: onOpen,
                    excludeSemantics: true,
                    child: InkWell(
                      key: const ValueKey('home-notification-open'),
                      onTap: onOpen,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 48),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(14, 6, 8, 6),
                          child: _body(context, current, extra, palette[2]),
                        ),
                      ),
                    ),
                  ),
                ),
                Semantics(
                  container: true,
                  button: true,
                  enabled: !busy,
                  label: '关闭当前通知',
                  onTap: busy ? null : onDismiss,
                  excludeSemantics: true,
                  child: IconButton(
                    key: const ValueKey('home-notification-dismiss'),
                    tooltip: '关闭当前通知',
                    onPressed: busy ? null : onDismiss,
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    icon: const Text(
                      '×',
                      style: TextStyle(
                        fontSize: 18,
                        height: 22 / 18,
                        color: Color(0xFF999999),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
              ],
            ),
          ),
        if (notice.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 6, 4),
            child: Row(
              children: [
                Expanded(
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      notice,
                      key: const ValueKey('home-notification-notice'),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6E6E73),
                      ),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: busy ? null : onRetry,
                  child: const Text('重试通知'),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _body(
    BuildContext context,
    HomeNotification current,
    String extra,
    Color iconColor,
  ) => LayoutBuilder(
    builder: (context, constraints) {
      const extraStyle = TextStyle(fontSize: 11, color: Color(0xFF007AFF));
      final measure = TextPainter(
        text: TextSpan(text: extra, style: extraStyle),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout();
      final inlineExtra =
          extra.isNotEmpty && constraints.maxWidth >= measure.width + 78;
      measure.dispose();
      final row = Row(
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: iconColor, shape: BoxShape.circle),
            child: Text(
              current.status == TaskStatus.completed ? '✓' : '!',
              textScaler: TextScaler.noScaling,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                height: 14 / 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              current.text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                height: 18 / 13,
                color: Color(0xFF333333),
              ),
            ),
          ),
          if (inlineExtra) ...[
            const SizedBox(width: 8),
            Text(
              extra,
              style: const TextStyle(fontSize: 11, color: Color(0xFF007AFF)),
            ),
          ],
        ],
      );
      return extra.isEmpty || inlineExtra
          ? row
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                row,
                const SizedBox(height: 4),
                Text(extra, style: extraStyle),
              ],
            );
    },
  );
}
