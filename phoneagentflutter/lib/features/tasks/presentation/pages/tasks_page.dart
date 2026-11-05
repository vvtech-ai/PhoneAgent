import 'package:flutter/material.dart';
import '../../../../core/design/native_navigation_backdrop.dart';
import '../../../../core/design/native_page_header.dart';
import '../../domain/task_records.dart';
import '../controller/task_controller.dart';
import 'task_record_card.dart';
import 'task_sync_surface.dart';
import 'task_actions.dart';
import 'task_status_label.dart';
import 'task_list_controls.dart';
import 'task_pagination_scroll_host.dart';
import '../../domain/task_record_presentation.dart';
import '../../domain/translation_task_presentation.dart';

class TasksPage extends StatelessWidget {
  const TasksPage({
    super.key,
    required this.state,
    required this.onRefresh,
    required this.onOpen,
    this.onLoadMore,
    this.onPin,
    this.onDelete,
    this.onClearUnread,
    this.scrollController,
    this.storageKey = 'tasks-scroll',
    this.focusedRecordId,
    this.focusedRecordKey,
    this.pinnedCollapsed = false,
    this.pinnedCount = 0,
    this.onTogglePinned,
  });
  final TaskState state;
  final Future<void> Function() onRefresh;
  final ValueChanged<TaskRecord> onOpen;
  final VoidCallback? onLoadMore, onClearUnread;
  final ValueChanged<TaskRecord>? onPin, onDelete;
  final ScrollController? scrollController;
  final String storageKey;
  final String? focusedRecordId;
  final Key? focusedRecordKey;
  final bool pinnedCollapsed;
  final int pinnedCount;
  final VoidCallback? onTogglePinned;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      NativePageHeader(
        title: '任务',
        showBack: false,
        trailing: onClearUnread == null
            ? null
            : TaskClearUnreadButton(
                onPressed:
                    state.hasUnread && !state.busy.contains('clear-unread')
                    ? onClearUnread
                    : null,
              ),
      ),
      Expanded(
        child: TaskPaginationScrollHost(
          state: state,
          onLoadMore: onLoadMore,
          child: RefreshIndicator(
            onRefresh: onRefresh,
            child: LayoutBuilder(
              builder: (context, constraints) => ListView(
                key: PageStorageKey(storageKey),
                controller: scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                // Keep the first card's shadow inside the clipped scroll viewport.
                padding: EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  16 + NativeNavigationBackdrop.contentInsetOf(context),
                ),
                children: [
                  if (state.notice.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(state.notice),
                    ),
                  if (state.loading && state.catalog.records.isNotEmpty)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 10),
                      child: TaskSyncSurface(error: false),
                    ),
                  if (state.catalog.failedSources.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: TaskSyncSurface(
                        error: true,
                        onRetry: state.loading ? null : onRefresh,
                      ),
                    ),
                  if (state.loading && state.catalog.records.isEmpty)
                    SizedBox(
                      height:
                          (constraints.maxHeight -
                                  32 -
                                  NativeNavigationBackdrop.contentInsetOf(
                                    context,
                                  ))
                              .clamp(0, double.infinity),
                      child: const TaskInitialLoading(),
                    ),
                  if (state.catalog.records.isEmpty &&
                      !state.loading &&
                      state.catalog.failedSources.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 60, bottom: 24),
                      child: Center(
                        child: Text(
                          '还没有任务记录',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF98A2B3),
                          ),
                        ),
                      ),
                    ),
                  for (final record in state.catalog.records.where(
                    (row) => row.pinnedAt != null,
                  ))
                    _record(context, record),
                  if (onTogglePinned != null)
                    TaskPinnedHeader(
                      collapsed: pinnedCollapsed,
                      count: pinnedCount,
                      onToggle: onTogglePinned!,
                    ),
                  for (final record in state.catalog.records.where(
                    (row) => row.pinnedAt == null,
                  ))
                    _record(context, record),
                  if (state.catalog.records.isNotEmpty &&
                      state.catalog.failedSources.isEmpty)
                    TaskPaginationFooter(state: state, onLoadMore: onLoadMore),
                ],
              ),
            ),
          ),
        ),
      ),
    ],
  );
  Widget _record(BuildContext context, TaskRecord record) => Padding(
    key: record.id == focusedRecordId ? focusedRecordKey : null,
    padding: const EdgeInsets.only(bottom: 10),
    child: Builder(builder: (rowContext) => _card(rowContext, record)),
  );
  Widget _card(
    BuildContext context,
    TaskRecord record, {
    bool preview = false,
  }) => TaskRecordCard(
    key: ValueKey(record.id),
    title: TaskRecordPresentation.title(record),
    detail: record.kind == TaskRecordKind.translation
        ? record.summary
        : TaskRecordPresentation.time(
            record.startedAt.isNotEmpty ? record.startedAt : record.timestamp,
          ).isEmpty
        ? '任务信息已同步'
        : TaskRecordPresentation.time(
            record.startedAt.isNotEmpty ? record.startedAt : record.timestamp,
          ),
    status: record.kind == TaskRecordKind.translation
        ? TranslationTaskPresentation.duration(record)
        : taskStatusLabel(record.rawStatus, record.status),
    statusColor: _color(record.status),
    onTap: () => onOpen(record),
    preview: preview,
    unread: record.kind != TaskRecordKind.translation && record.unreadResult,
    pinned: record.pinnedAt != null,
    enabled: !state.busy.contains(record.ref?.key),
    onLongPress:
        !preview && record.ref != null && onPin != null && onDelete != null
        ? () => showTaskActions(
            context,
            record,
            preview: _card(context, record, preview: true),
            onPin: onPin!,
            onDelete: onDelete!,
          )
        : null,
  );
  static Color _color(TaskStatus value) => switch (value) {
    TaskStatus.completed => const Color(0xFF1F8F46),
    TaskStatus.incomplete => const Color(0xFFFF9F0A),
    TaskStatus.executionError => const Color(0xFFDC2626),
    TaskStatus.running => const Color(0xFF3B82F6),
  };
}
