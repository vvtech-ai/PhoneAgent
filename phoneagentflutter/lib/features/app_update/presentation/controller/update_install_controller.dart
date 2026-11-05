import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/app_update.dart';
import '../../domain/update_install.dart';

enum UpdateInstallPhase {
  idle,
  restoring,
  downloading,
  paused,
  ready,
  permission,
  installing,
  failed,
}

class UpdateInstallState {
  const UpdateInstallState({
    this.phase = UpdateInstallPhase.idle,
    this.progress,
    this.error = '',
    this.busy = false,
  });
  final UpdateInstallPhase phase;
  final double? progress;
  final String error;
  final bool busy;
}

class UpdateInstallController extends StateNotifier<UpdateInstallState> {
  UpdateInstallController({
    required this.app,
    required this.release,
    required this.port,
    required this.isCurrent,
    this.interval = const Duration(milliseconds: 500),
    Future<void> Function(Duration)? delay,
  }) : _delay = delay ?? Future<void>.delayed,
       super(const UpdateInstallState());
  final InstalledApp app;
  final AppUpdateRelease release;
  final UpdateInstallPort port;
  final bool Function() isCurrent;
  final Duration interval;
  final Future<void> Function(Duration) _delay;
  String? _job;
  int _generation = 0;
  bool _started = false, _cancelled = false, _permissionPending = false;
  bool _resumePending = false;
  bool get _current => mounted && !_cancelled && isCurrent();
  bool _same(int generation) => _current && generation == _generation;

  Future<void> restore() async {
    if (!_current || _started) return;
    _started = true;
    final generation = ++_generation;
    _set(UpdateInstallPhase.restoring, busy: true);
    try {
      final download = await port.restore(release);
      if (!_same(generation)) {
        if (_cancelled && download != null) await port.cancel(download.job);
        return;
      }
      if (download == null) {
        _set(UpdateInstallPhase.idle);
        return;
      }
      _job = download.job;
      // Recovery must not unexpectedly launch an installer without a fresh action.
      await _observe(download, generation, autoInstall: false);
    } catch (_) {
      if (_same(generation)) _fail('更新任务恢复失败，请重试');
    }
  }

  Future<void> primary() async {
    if (!_current || state.busy) return;
    if (state.phase == UpdateInstallPhase.ready ||
        state.phase == UpdateInstallPhase.permission) {
      await _handoff();
      return;
    }
    if (state.phase != UpdateInstallPhase.idle &&
        state.phase != UpdateInstallPhase.failed) {
      return;
    }
    final generation = ++_generation;
    _set(UpdateInstallPhase.downloading, busy: true);
    try {
      final previous = _job;
      if (previous != null) await port.cancel(previous);
      if (!_same(generation)) return;
      _job = null;
      final download = await port.begin(release);
      if (!_same(generation)) {
        if (_cancelled) await port.cancel(download.job);
        return;
      }
      _job = download.job;
      await _observe(download, generation, autoInstall: true);
    } catch (_) {
      if (_same(generation)) _fail('下载未完成，可重新下载');
    }
  }

  Future<void> _observe(
    UpdateDownload download,
    int generation, {
    required bool autoInstall,
  }) async {
    var current = download;
    while (_same(generation)) {
      if (current.job != _job) throw StateError('Download ownership mismatch');
      switch (current.status) {
        case UpdateDownloadStatus.failed:
          _fail('下载失败，可重新下载');
          return;
        case UpdateDownloadStatus.downloaded:
          _set(UpdateInstallPhase.ready, progress: 1);
          if (_same(generation) &&
              state.phase == UpdateInstallPhase.ready &&
              autoInstall) {
            await _handoff();
          }
          return;
        case UpdateDownloadStatus.downloading:
        case UpdateDownloadStatus.paused:
          _set(
            current.status == UpdateDownloadStatus.paused
                ? UpdateInstallPhase.paused
                : UpdateInstallPhase.downloading,
            busy: true,
            progress: current.progress,
          );
          await _delay(interval);
          if (!_same(generation)) return;
          current = await port.query(_job!);
      }
    }
  }

  Future<void> _handoff() async {
    if (!_current || _job == null || state.busy) return;
    final generation = ++_generation;
    _set(UpdateInstallPhase.ready, busy: true, progress: 1);
    try {
      final allowed = await port.canInstall();
      if (!_same(generation)) return;
      if (!allowed) {
        _permissionPending = true;
        _set(UpdateInstallPhase.permission, busy: true, progress: 1);
        await port.openPermission();
        if (_same(generation)) _set(UpdateInstallPhase.permission, progress: 1);
      } else {
        _permissionPending = false;
        _set(UpdateInstallPhase.installing, busy: true, progress: 1);
        await port.install(_job!);
        // Only lifecycle/version reconciliation can advance from a handoff.
        if (_same(generation)) _set(UpdateInstallPhase.installing, progress: 1);
      }
    } on UpdateDownloadUnavailable {
      if (_same(generation)) {
        _permissionPending = false;
        _fail('下载文件不可用，请重新下载');
      }
    } catch (_) {
      if (_same(generation)) {
        _permissionPending = false;
        _set(UpdateInstallPhase.ready, error: '无法交接系统安装，请重试');
      }
    } finally {
      if (_same(generation) && _resumePending) {
        _resumePending = false;
        await resumed();
      }
    }
  }

  Future<void> resumed() async {
    if (!_current) return;
    if (state.busy) {
      if (state.phase == UpdateInstallPhase.permission ||
          state.phase == UpdateInstallPhase.installing) {
        _resumePending = true;
      }
      return;
    }
    if (_permissionPending && state.phase == UpdateInstallPhase.permission) {
      _permissionPending = false;
      _set(UpdateInstallPhase.permission, busy: true, progress: 1);
      try {
        final allowed = await port.canInstall();
        if (!_current) return;
        _set(
          UpdateInstallPhase.permission,
          progress: 1,
          error: allowed ? '' : '尚未授权安装，可再次点击授权',
        );
        if (allowed) await _handoff();
      } catch (_) {
        if (_current) {
          _set(UpdateInstallPhase.permission, error: '无法查询安装授权，请重试');
        }
      }
    } else if (state.phase == UpdateInstallPhase.installing) {
      _set(UpdateInstallPhase.ready, progress: 1, error: '安装未完成，可再次点击安装继续更新');
    }
  }

  Future<bool> cancel() async {
    if (!mounted || _cancelled) return false;
    _cancelled = true;
    ++_generation;
    final job = _job;
    try {
      if (job != null) await port.cancel(job);
      return true;
    } catch (_) {
      if (mounted) {
        _cancelled = false;
        _fail('下载清理失败，请重试关闭');
      }
      return false;
    }
  }

  void _fail(String error) => _set(UpdateInstallPhase.failed, error: error);
  void _set(
    UpdateInstallPhase phase, {
    bool busy = false,
    double? progress,
    String error = '',
  }) {
    if (_current) {
      state = UpdateInstallState(
        phase: phase,
        busy: busy,
        progress: progress,
        error: error,
      );
    }
  }

  @override
  void dispose() {
    ++_generation;
    super.dispose();
  }
}
