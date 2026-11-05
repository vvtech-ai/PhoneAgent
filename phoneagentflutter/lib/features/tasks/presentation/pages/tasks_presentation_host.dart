import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/design/native_notice.dart';
import '../../../../core/design/page_route_visibility.dart';
import '../../domain/task_records.dart';
import '../../domain/task_pinned_visibility.dart';
import '../controller/task_controller.dart';
import '../controller/task_operation_feedback.dart';
import '../controller/task_operation_trace.dart';
import 'tasks_page.dart';

class TasksPresentationHost extends StatefulWidget {
  const TasksPresentationHost({
    super.key,
    required this.state,
    required this.preferences,
    required this.onRefresh,
    required this.onOpen,
    required this.onPin,
    required this.onDelete,
    required this.onClearUnread,
    required this.onLoadMore,
  });
  final TaskState state;
  final TaskPinnedPreferenceRepository preferences;
  final Future<void> Function() onRefresh;
  final ValueChanged<TaskRecord> onOpen, onDelete;
  final Future<bool> Function(TaskRecord) onPin;
  final VoidCallback onClearUnread, onLoadMore;
  @override
  State<TasksPresentationHost> createState() => _TasksHostState();
}

class _TasksHostState extends State<TasksPresentationHost> {
  final _scroll = ScrollController(), _focusKey = GlobalKey();
  bool _collapsed = false, _edited = false, _readFailed = false;
  String? _focusId;
  String _notice = '';
  Future<void> _writes = Future.value();
  StreamSubscription<TaskOperationFeedback>? _feedback;
  Object _noticeOwner = Object();
  ModalRoute<dynamic>? _route;
  PageRouteVisibilityObserver? _pageVisibility;
  bool _active = true;
  bool get _visiblePage =>
      _route != null && identical(_pageVisibility?.currentPage, _route);
  @override
  void initState() {
    super.initState();
    _listenFeedback();
    unawaited(_load());
  }

  void _listenFeedback() {
    unawaited(_feedback?.cancel());
    _feedback = widget.state.operationFeedback?.listen((result) {
      void trace(TaskOperationTraceStage stage) => traceTaskOperation(
        stage,
        result.operation,
        mounted: mounted,
        active: _active,
        visiblePage: _visiblePage,
        succeeded: result.succeeded,
      );
      trace(TaskOperationTraceStage.hostReceived);
      if (!mounted || !_active || !_visiblePage) {
        trace(TaskOperationTraceStage.hostSuppressed);
        return;
      }
      showNativeNotice(context, result.message, owner: _noticeOwner);
      trace(TaskOperationTraceStage.noticeRequested);
    });
  }

  void _invalidateFeedback() {
    dismissNativeNotice(owner: _noticeOwner);
    _noticeOwner = Object();
  }

  void _pageChanged() {
    if (!_visiblePage) _invalidateFeedback();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of(context);
    final visibility = PageRouteVisibilityScope.of(context);
    if (!identical(visibility, _pageVisibility)) {
      _pageVisibility?.removeListener(_pageChanged);
      _pageVisibility = visibility;
      _pageVisibility?.addListener(_pageChanged);
    }
    _pageChanged();
  }

  @override
  void deactivate() {
    _active = false;
    _invalidateFeedback();
    super.deactivate();
  }

  @override
  void activate() {
    super.activate();
    _active = true;
  }

  @override
  void didUpdateWidget(covariant TasksPresentationHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.operationFeedback != widget.state.operationFeedback ||
        oldWidget.preferences.scopeKey != widget.preferences.scopeKey) {
      _invalidateFeedback();
      _listenFeedback();
    }
  }

  Future<void> _load() async {
    try {
      final value = await widget.preferences.read();
      if (mounted && !_edited) {
        setState(() {
          _collapsed = value;
          _notice = '';
          _readFailed = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _notice = '置顶折叠偏好读取失败，可重试。';
          _readFailed = true;
        });
      }
    }
  }

  void _save(bool value) {
    _edited = true;
    setState(() {
      _collapsed = value;
      _notice = '';
      _readFailed = false;
    });
    final store = widget.preferences;
    _writes = _writes
        .catchError((_) {})
        .then((_) => store.save(value))
        .catchError((_) {
          if (mounted) setState(() => _notice = '置顶折叠偏好保存失败，可重试。');
        });
  }

  void _toggle() {
    _save(!_collapsed);
    if (!_collapsed && _scroll.hasClients) _scroll.jumpTo(0);
  }

  Future<void> _pin(TaskRecord row) async {
    if (!await widget.onPin(row) || !mounted || row.pinnedAt != null) return;
    _save(false);
    setState(() => _focusId = row.id);
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || !_scroll.hasClients) return;
    _scroll.jumpTo(0);
    await WidgetsBinding.instance.endOfFrame;
    while (mounted &&
        _scroll.hasClients &&
        _focusKey.currentContext == null &&
        _scroll.offset < _scroll.position.maxScrollExtent) {
      _scroll.jumpTo(
        (_scroll.offset + _scroll.position.viewportDimension).clamp(
          0,
          _scroll.position.maxScrollExtent,
        ),
      );
      await WidgetsBinding.instance.endOfFrame;
    }
    if (mounted && _focusKey.currentContext != null) {
      await Scrollable.ensureVisible(
        _focusKey.currentContext!,
        duration: const Duration(milliseconds: 200),
      );
    }
  }

  @override
  void dispose() {
    _pageVisibility?.removeListener(_pageChanged);
    _invalidateFeedback();
    unawaited(_feedback?.cancel());
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visible = TaskPinnedVisibility(
      widget.state.catalog.records,
      _collapsed,
    );
    final pins = widget.state.catalog.records
        .where((r) => r.pinnedAt != null)
        .length;
    return Column(
      children: [
        if (_notice.isNotEmpty)
          ListTile(
            title: Text(_notice),
            trailing: TextButton(
              onPressed: () => _readFailed ? _load() : _save(_collapsed),
              child: const Text('重试'),
            ),
          ),
        Expanded(
          child: TasksPage(
            state: widget.state.copy(
              catalog: TaskCatalog(
                visible.visible,
                failedSources: widget.state.catalog.failedSources,
              ),
            ),
            onRefresh: widget.onRefresh,
            onOpen: widget.onOpen,
            onPin: _pin,
            onDelete: widget.onDelete,
            onClearUnread: widget.onClearUnread,
            onLoadMore: widget.onLoadMore,
            scrollController: _scroll,
            storageKey: widget.preferences.scopeKey,
            focusedRecordId: _focusId,
            focusedRecordKey: _focusKey,
            pinnedCollapsed: _collapsed,
            pinnedCount: _collapsed ? visible.hiddenCount : pins,
            onTogglePinned: pins > 0 && (!_collapsed || visible.hiddenCount > 0)
                ? _toggle
                : null,
          ),
        ),
      ],
    );
  }
}
