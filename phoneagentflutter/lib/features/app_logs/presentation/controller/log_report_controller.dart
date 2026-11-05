import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/app_log_report.dart';

enum LogReportPhase {
  idle,
  preparing,
  ready,
  uploading,
  failed,
  cleanupFailed,
  success,
}

class LogReportState {
  const LogReportState(this.phase, {this.bundle});
  final LogReportPhase phase;
  final AppLogBundle? bundle;
  bool get busy =>
      phase == LogReportPhase.preparing || phase == LogReportPhase.uploading;
}

class LogReportController extends StateNotifier<LogReportState> {
  LogReportController(this.repository)
    : super(const LogReportState(LogReportPhase.idle));
  final AppLogRepository repository;
  LogReportState get snapshot => state;
  bool _uploaded = false;

  /// One explicit native settings entry action; never drains remaining batches.
  Future<void> submitFromEntry() async {
    if (!mounted || state.busy) return;
    if (state.phase == LogReportPhase.cleanupFailed) {
      await retryCleanup();
      return;
    }
    if (state.phase == LogReportPhase.success) {
      _uploaded = false;
      state = const LogReportState(LogReportPhase.idle);
    }
    if (state.bundle == null) await prepare();
    if (!mounted ||
        state.phase != LogReportPhase.ready &&
            state.phase != LogReportPhase.failed) {
      return;
    }
    await upload();
  }

  Future<void> prepare() async {
    if (!mounted || state.busy || _uploaded) return;
    state = const LogReportState(LogReportPhase.preparing);
    try {
      final bundle = await repository.prepare();
      if (mounted) state = LogReportState(LogReportPhase.ready, bundle: bundle);
    } catch (_) {
      if (mounted) state = const LogReportState(LogReportPhase.failed);
    }
  }

  Future<void> upload() async {
    if (!mounted || state.busy || _uploaded || state.bundle == null) return;
    final bundle = state.bundle!;
    state = LogReportState(LogReportPhase.uploading, bundle: bundle);
    try {
      await repository.upload(bundle);
      _uploaded = true;
      // Cleanup belongs to this captured account snapshot even if page closed.
      await _cleanup(bundle);
    } catch (_) {
      if (mounted) {
        state = LogReportState(LogReportPhase.failed, bundle: bundle);
      }
    }
  }

  Future<void> prepareNext() async {
    if (!mounted ||
        state.phase != LogReportPhase.success ||
        state.bundle?.hasMore != true) {
      return;
    }
    _uploaded = false;
    state = const LogReportState(LogReportPhase.idle);
    await prepare();
  }

  Future<void> retryCleanup() async {
    if (!mounted ||
        state.busy ||
        !_uploaded ||
        state.bundle == null ||
        state.phase != LogReportPhase.cleanupFailed) {
      return;
    }
    final bundle = state.bundle!;
    state = LogReportState(LogReportPhase.uploading, bundle: bundle);
    await _cleanup(bundle);
  }

  Future<void> _cleanup(AppLogBundle bundle) async {
    try {
      await repository.acknowledge(bundle);
      if (mounted) {
        state = LogReportState(LogReportPhase.success, bundle: bundle);
      }
    } catch (_) {
      if (mounted) {
        state = LogReportState(LogReportPhase.cleanupFailed, bundle: bundle);
      }
    }
  }
}
