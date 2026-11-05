import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../domain/drafts/task_draft.dart';

/// Owns the edit buffer and its submission acknowledgement, not conversation state.
class TaskDraftController extends ChangeNotifier {
  TaskDraftController(
    this.repository, {
    required this.pendingCommand,
    required this.notice,
    this.acceptedCommandsBeforeSend,
  });
  final TaskDraftRepository repository;
  final String? Function(String) pendingCommand;
  final void Function(String) notice;
  final Set<String> Function()? acceptedCommandsBeforeSend;
  Set<String> _previousAccepted = {};
  TaskDraft value = const TaskDraft('');
  TaskDraft? _submitted;
  String? _command;
  bool _closed = false, ready = false;
  int _revision = 0;
  int _submittedRevision = -1;
  String? get submittedText => _submitted?.text;
  Future<void> load() async {
    final revision = _revision;
    try {
      final saved = await repository.read();
      if (_closed) return;
      if (revision == _revision && saved != null) value = saved;
    } catch (_) {
      if (!_closed) notice('草稿读取失败，可继续输入。');
    }
    if (!_closed) {
      ready = true;
      notifyListeners();
    }
  }

  void edit(TaskDraft draft) {
    if (_closed) return;
    _revision++;
    value = draft;
    _persist(draft.text.isEmpty ? null : draft);
  }

  bool submit(bool Function(String) send) {
    if (_closed || !ready || value.text.trim().isEmpty) return false;
    final draft = value;
    _previousAccepted = acceptedCommandsBeforeSend?.call() ?? {};
    if (!send(draft.text)) return false;
    _submitted = draft;
    _command = pendingCommand(draft.text);
    _revision++;
    _submittedRevision = _revision;
    value = const TaskDraft('');
    _persist(null);
    notifyListeners();
    if (_command == null) accepted();
    return true;
  }

  void observe(
    Set<String> acceptedCommands,
    bool failed, {
    String? nextCommand,
    bool settled = false,
  }) {
    if (_closed || _command == null) return;
    if (_command == 'awaiting-input' &&
        nextCommand != null &&
        nextCommand != 'awaiting-input' &&
        !_previousAccepted.contains(nextCommand)) {
      _command = nextCommand;
    }
    if (acceptedCommands.contains(_command)) {
      accepted();
    } else if (failed) {
      if (_revision == _submittedRevision &&
          value.text.isEmpty &&
          _submitted != null) {
        value = _submitted!;
        _revision++;
        notifyListeners();
        _persist(value);
      }
      _command = null;
      _submitted = null;
    } else if (settled && _command == 'awaiting-input') {
      accepted();
    }
  }

  void accepted() {
    _command = null;
    _submitted = null;
    if (_revision == _submittedRevision && value.text.isEmpty) _persist(null);
  }

  void _persist(TaskDraft? draft) {
    // Register immediately in the repository's shared queue: a newly opened
    // controller must read after this controller's pending save or deletion.
    unawaited(
      repository.save(draft).catchError((Object _) {
        if (!_closed) notice('草稿保存失败，请重试输入或保留当前页面。');
      }),
    );
  }

  @override
  void dispose() {
    _closed = true;
    super.dispose();
  }
}
