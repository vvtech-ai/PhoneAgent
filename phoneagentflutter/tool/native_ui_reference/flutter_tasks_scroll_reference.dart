import 'package:flutter/material.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/native_conversation_background.dart';
import 'package:phone_agent/features/tasks/domain/task_records.dart';
import 'package:phone_agent/features/tasks/presentation/controller/task_controller.dart';
import 'package:phone_agent/features/tasks/presentation/pages/tasks_page.dart';

/// Pure synthetic data, actual production list, and user gestures only.
class FlutterTasksScrollReference extends StatefulWidget {
  const FlutterTasksScrollReference({super.key});

  @override
  State<FlutterTasksScrollReference> createState() => _TasksScrollState();
}

class _TasksScrollState extends State<FlutterTasksScrollReference> {
  final _reading = ValueNotifier<String>('手势滚动待验');
  bool _large = false;
  final _state = TaskState(
    catalog: TaskCatalog([
      for (var i = 0; i < 30; i++)
        TaskRecord(
          id: 'synthetic-scroll-$i',
          kind: TaskRecordKind.conversation,
          title: '合成任务 ${(i + 1).toString().padLeft(2, '0')}',
          status: TaskStatus.completed,
          rawStatus: 'CLOSED',
          timestamp: '2026-09-20T09:00:00',
        ),
    ]),
  );

  void _observe(ScrollMetrics metrics) {
    final text =
        '位置 ${metrics.pixels.toStringAsFixed(1)} / '
        '${metrics.maxScrollExtent.toStringAsFixed(1)}';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _reading.value != text) _reading.value = text;
    });
  }

  @override
  void dispose() {
    _reading.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: NativeConversationBackground(
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(_large ? 2 : 1)),
                child: NotificationListener<ScrollMetricsNotification>(
                  onNotification: (notice) {
                    if (notice.depth == 0) _observe(notice.metrics);
                    return false;
                  },
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (notice) {
                      if (notice.depth == 0) _observe(notice.metrics);
                      return false;
                    },
                    child: TasksPage(
                      state: _state,
                      onRefresh: () async {},
                      onOpen: (_) {},
                    ),
                  ),
                ),
              ),
            ),
            ValueListenableBuilder<String>(
              valueListenable: _reading,
              builder: (_, text, __) => Text(text),
            ),
            TextButton(
              onPressed: () => setState(() => _large = !_large),
              child: Text(_large ? '切换普通字号' : '切换两倍字号'),
            ),
          ],
        ),
      ),
    ),
  );
}
