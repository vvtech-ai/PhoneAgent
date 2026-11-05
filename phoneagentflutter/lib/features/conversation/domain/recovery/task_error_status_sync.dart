import 'dart:async';
import '../conversation_ids.dart';
import 'task_error_status_command.dart';

enum TaskErrorSyncEvent {
  queued,
  persisted,
  synchronized,
  storageFailed,
  requestFailed,
}

typedef TaskErrorSyncObserver =
    void Function(TaskErrorSyncEvent, TaskErrorStatusCommand?);

/// One instance per account lease. No retry timers, generic interrupt reasons,
/// user-turn replay or audio ownership live here.
class TaskErrorStatusSync {
  TaskErrorStatusSync({
    required TaskErrorStatusStore store,
    required TaskErrorStatusGateway gateway,
    required bool Function() isCurrent,
    String Function()? nextId,
    this.observe,
  }) : _store = store,
       _gateway = gateway,
       _isCurrent = isCurrent,
       _nextId = nextId ?? _newCommandId;

  static String _newCommandId() {
    final id = newConversationId();
    return '${id.substring(0, 8)}-${id.substring(8, 12)}-'
        '${id.substring(12, 16)}-${id.substring(16, 20)}-${id.substring(20)}';
  }

  final TaskErrorStatusStore _store;
  final TaskErrorStatusGateway _gateway;
  final bool Function() _isCurrent;
  final String Function() _nextId;
  final TaskErrorSyncObserver? observe;
  final _changes = StreamController<void>.broadcast();
  Stream<void> get changes => _changes.stream;
  final _commands = <String, TaskErrorStatusCommand>{};
  final _dirty = <String, TaskErrorStatusCommand>{};
  final _saving = <String, Future<bool>>{};
  final _acknowledged = <String, String>{};
  bool _loaded = false, _closed = false;
  Future<void>? _flight;
  Future<bool>? _loading;

  bool get _active => !_closed && _isCurrent();
  Set<String> get pendingExitSessions => Set.unmodifiable(
    _commands.values
        .where(
          (c) =>
              c.reason == TaskErrorStatusReason.exited &&
              !_acknowledged.containsKey(c.commandId),
        )
        .map((c) => c.sessionId),
  );
  bool get hasPending => _commands.isNotEmpty;

  Future<bool> restorePending() async =>
      _active && await _load() && _active && hasPending;

  Future<void> record(String sessionId, TaskErrorStatusReason reason) {
    if (!_active) return Future.value();
    final command = TaskErrorStatusCommand(sessionId, reason, _nextId());
    _acknowledged.remove(_commands[sessionId]?.commandId);
    // Update synchronously so a late in-flight acknowledgement cannot clear it.
    _commands[sessionId] = command;
    _dirty[sessionId] = command;
    _emit(TaskErrorSyncEvent.queued, command);
    // Persist independently of a slow older HTTP request. Otherwise killing
    // the app during that request could resurrect the old exit after recovery.
    return _persist(command).then((saved) async {
      if (saved) await flush();
    });
  }

  Future<void> flush() {
    if (!_active) return Future.value();
    return _flight ??= Future<void>.microtask(_flush).whenComplete(() {
      _flight = null;
    });
  }

  Future<void> _flush() async {
    if (!_active || !await _load()) return;
    // Each command is attempted at most once per explicit trigger. Newly queued
    // versions can follow an older flight without retrying a failed old version.
    final attempted = <String>{};
    while (_active) {
      final commands = _commands.values
          .where((c) => !attempted.contains(c.commandId))
          .toList();
      if (commands.isEmpty) return;
      for (final command in commands) {
        if (!_active) return;
        if (!_matches(command)) continue;
        attempted.add(command.commandId);
        if (!await _persist(command) || !_active || !_matches(command)) {
          continue;
        }
        if (!_acknowledged.containsKey(command.commandId)) {
          try {
            final status = await _gateway.send(command);
            if (!_active) return;
            if (!_matches(command)) continue;
            _acknowledged[command.commandId] = status;
            _changes.add(null);
          } catch (_) {
            _emit(TaskErrorSyncEvent.requestFailed, command);
            continue;
          }
        }
        if (!_active) return;
        if (!_matches(command)) continue;
        try {
          await _store.removeIfCurrent(command);
          if (!_active) return;
          if (_matches(command)) _commands.remove(command.sessionId);
          _acknowledged.remove(command.commandId);
          _emit(TaskErrorSyncEvent.synchronized, command);
        } catch (_) {
          _emit(TaskErrorSyncEvent.storageFailed, command);
        }
      }
    }
  }

  Future<bool> _load() {
    if (_loaded) return Future.value(true);
    return _loading ??= Future<bool>.microtask(() async {
      try {
        final stored = await _store.read();
        if (!_active) return false;
        for (final command in stored) {
          _commands.putIfAbsent(command.sessionId, () => command);
        }
        _loaded = true;
        return true;
      } catch (_) {
        _emit(TaskErrorSyncEvent.storageFailed, null);
        return false;
      }
    }).whenComplete(() => _loading = null);
  }

  Future<bool> _persist(TaskErrorStatusCommand command) {
    return _saving.putIfAbsent(
      command.commandId,
      () =>
          Future<bool>.microtask(() async {
            if (!_active || !await _load() || !_active || !_matches(command)) {
              return false;
            }
            if (!_dirty.containsKey(command.sessionId)) return true;
            try {
              await _store.put(command);
              if (!_active || !_matches(command)) return false;
              _dirty.remove(command.sessionId);
              _emit(TaskErrorSyncEvent.persisted, command);
              return true;
            } catch (_) {
              _emit(TaskErrorSyncEvent.storageFailed, command);
              return false;
            }
          }).whenComplete(() {
            _saving.remove(command.commandId);
          }),
    );
  }

  bool _matches(TaskErrorStatusCommand command) =>
      _commands[command.sessionId]?.commandId == command.commandId;

  void _emit(TaskErrorSyncEvent event, TaskErrorStatusCommand? command) {
    if (!_active) return;
    _changes.add(null);
    try {
      observe?.call(event, command);
    } catch (_) {
      /* isolated telemetry */
    }
  }

  void close() {
    if (_closed) return;
    _closed = true;
    unawaited(_changes.close());
  }
}
