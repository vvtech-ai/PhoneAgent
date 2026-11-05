import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/app_update.dart';

class AppUpdateState {
  const AppUpdateState({
    this.busy = false,
    this.app,
    this.release,
    this.error = '',
  });
  final bool busy;
  final InstalledApp? app;
  final AppUpdateRelease? release;
  final String error;
}

class AppUpdateController extends StateNotifier<AppUpdateState> {
  AppUpdateController(this.source, this.repository, {this.onChecked})
    : super(const AppUpdateState());
  final InstalledAppSource source;
  final AppUpdateRepository repository;
  final Future<void> Function(InstalledApp, AppUpdateRelease)? onChecked;
  bool _closed = false;
  Future<void> check() async {
    if (_closed || state.busy) return;
    state = AppUpdateState(busy: true, app: state.app);
    InstalledApp? app;
    try {
      app = await source.read();
      if (_closed) return;
      if (!app.valid) throw const FormatException('Invalid installed identity');
      final release = await repository.check(app);
      if (_closed) return;
      await onChecked?.call(app, release);
      if (!_closed) state = AppUpdateState(app: app, release: release);
    } catch (_) {
      if (!_closed) {
        state = AppUpdateState(
          app: app,
          error: app == null ? '无法读取当前安装版本，请重试' : '版本检查失败，请稍后重试',
        );
      }
    }
  }

  @override
  void dispose() {
    _closed = true;
    super.dispose();
  }
}
