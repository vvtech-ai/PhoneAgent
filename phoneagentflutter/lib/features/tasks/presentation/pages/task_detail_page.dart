import 'package:flutter/material.dart';
import '../../../conversation/domain/conversation_messages.dart';
import '../../domain/task_records.dart';
import '../../../conversation/presentation/widgets/conversation_message_tile.dart';
import '../controller/task_detail_controller.dart';
import 'task_status_label.dart';

class TaskDetailPage extends StatelessWidget {
  const TaskDetailPage({
    super.key,
    required this.state,
    required this.onClose,
    required this.onRetry,
    required this.onRestore,
    this.recordingBuilder,
    this.receiptFeedbackBuilder,
    this.artifactOwner,
  });
  final TaskDetailState state;
  final VoidCallback onClose, onRetry, onRestore;
  final Widget Function(String, bool)? recordingBuilder;
  final Widget? Function(ConversationMessage)? receiptFeedbackBuilder;
  final Object? artifactOwner;
  @override
  Widget build(BuildContext context) {
    final row = state.record, legacy = state.legacy;
    return Scaffold(
      appBar: AppBar(
        title: const Text('任务详情'),
        leading: IconButton(
          tooltip: '关闭任务详情',
          onPressed: onClose,
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      bottomNavigationBar:
          row.canRestore ||
              row.taskId != null ||
              row.kind == TaskRecordKind.call
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton(
                  key: const ValueKey('task-detail-restore'),
                  onPressed: state.canRestore || state.canOpenLegacy
                      ? onRestore
                      : null,
                  child: Text(row.canRestore ? '恢复对话' : '进入任务对话'),
                ),
              ),
            )
          : null,
      body: SafeArea(
        child: ListView(
          key: const ValueKey('task-detail-scroll'),
          padding: const EdgeInsets.all(20),
          children: [
            Text(state.title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Text(
              '状态：${taskStatusLabel(state.rawStatus, row.status)}',
              key: const ValueKey('task-detail-status'),
            ),
            if (row.scene.isNotEmpty) Text('场景：${row.scene}'),
            Text('任务：${row.sessionId ?? row.taskId ?? row.callId ?? row.id}'),
            if (row.timestamp.isNotEmpty) Text(row.timestamp),
            if (state.loading) const LinearProgressIndicator(),
            if (state.notice.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(state.notice),
              ),
            if (state.failed)
              TextButton(onPressed: onRetry, child: const Text('重新加载详情')),
            if (!state.loading && !state.failed) ...[
              if (row.summary.isNotEmpty &&
                  state.restored == null &&
                  legacy == null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(row.summary),
                ),
              if (legacy != null) ...[
                if (legacy.result.isNotEmpty) Text(legacy.result),
                for (final field in legacy.fields.entries)
                  Text('${field.key}：${field.value}'),
                for (final call in legacy.calls)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('通话：${call.callId} · ${call.status}'),
                          Text(call.result),
                          Text(call.summary),
                          if (call.callId.isNotEmpty &&
                              recordingBuilder != null)
                            recordingBuilder!(call.callId, false),
                        ],
                      ),
                    ),
                  ),
              ],
              if (row.dialogue.isNotEmpty) Text(row.dialogue),
              if (state.restored != null)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('历史对话与执行结果'),
                ),
              for (final message in state.messages)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ConversationMessageTile(
                      key: ValueKey('detail:${message.id}'),
                      message: message,
                      optionsEnabled: false,
                      onChoose: (_) {},
                      recordingBuilder: recordingBuilder,
                      artifactOwner: artifactOwner,
                    ),
                    if (receiptFeedbackBuilder?.call(message)
                        case final Widget feedback)
                      feedback,
                  ],
                ),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
