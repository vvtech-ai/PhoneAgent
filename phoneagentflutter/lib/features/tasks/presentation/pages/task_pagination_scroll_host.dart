import 'package:flutter/material.dart';
import '../controller/task_controller.dart';

/// Native footer visibility drives paging; the task controller owns requests.
class TaskPaginationScrollHost extends StatefulWidget {
  const TaskPaginationScrollHost({
    super.key,
    required this.state,
    required this.child,
    this.onLoadMore,
  });
  final TaskState state;
  final Widget child;
  final VoidCallback? onLoadMore;
  @override
  State<TaskPaginationScrollHost> createState() => _PaginationState();
}

class _PaginationState extends State<TaskPaginationScrollHost> {
  ScrollMetrics? _metrics;
  bool _scheduled = false, _requested = false;
  @override
  void didUpdateWidget(covariant TaskPaginationScrollHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state != oldWidget.state) {
      _requested = false;
      _schedule();
    }
  }

  void _schedule() {
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted || _requested || _metrics == null) return;
      final state = widget.state;
      if (state.loading ||
          state.loadingMore ||
          state.moreFailed ||
          !state.hasMore ||
          state.busy.isNotEmpty ||
          state.catalog.failedSources.isNotEmpty ||
          state.catalog.records.isEmpty ||
          _metrics!.extentAfter > 72) {
        return;
      }
      _requested = true;
      widget.onLoadMore?.call();
    });
  }

  @override
  Widget build(BuildContext context) =>
      NotificationListener<ScrollMetricsNotification>(
        onNotification: (event) {
          if (event.depth == 0) {
            _metrics = event.metrics;
            _schedule();
          }
          return false;
        },
        child: NotificationListener<ScrollNotification>(
          onNotification: (event) {
            if (event.depth == 0) {
              _metrics = event.metrics;
              if (event.metrics.extentAfter > 72) _requested = false;
              _schedule();
            }
            return false;
          },
          child: widget.child,
        ),
      );
}
