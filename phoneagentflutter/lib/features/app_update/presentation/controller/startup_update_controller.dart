import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/app_update.dart';
import '../../domain/startup_update.dart';

class StartupUpdateState {
  const StartupUpdateState({this.busy = false, this.offer, this.notice = ''});
  final bool busy;
  final StartupUpdateOffer? offer;
  final String notice;
}

/// v65: successful local-day throttle, persistent force triggers recheck only.
/// Network failure alone must not introduce an offline lockout.
class StartupUpdateController extends StateNotifier<StartupUpdateState> {
  StartupUpdateController({
    required this.source,
    required this.repository,
    required this.store,
    required this.recovery,
    required this.isCurrent,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now,
       super(const StartupUpdateState());
  final InstalledAppSource source;
  final AppUpdateRepository repository;
  final StartupUpdateStore store;
  final StartupUpdateRecovery recovery;
  final bool Function() isCurrent;
  final DateTime Function() _now;
  bool _started = false;
  int _generation = 0;
  StartupUpdateRecord _record = const StartupUpdateRecord();
  AppUpdateRelease? _lastAccepted;
  bool get _current => mounted && isCurrent();
  bool _same(int generation) => _current && generation == _generation;

  Future<void> start() async {
    if (!_current || _started) return;
    _started = true;
    final generation = ++_generation;
    state = const StartupUpdateState(busy: true);
    try {
      final app = await source.read();
      if (!_same(generation)) return;
      if (!app.valid) throw const FormatException('Invalid installed app');
      // Recovery has priority even while offline. It never enqueues or installs.
      final recovered = await recovery.peek(app);
      if (!_same(generation)) return;
      if (recovered != null) {
        _validate(app, recovered);
        state = StartupUpdateState(
          offer: StartupUpdateOffer(app, recovered, recovered: true),
        );
        return;
      }
      try {
        _record = await store.read(app);
      } catch (_) {
        if (_same(generation)) {
          state = const StartupUpdateState(notice: '无法读取更新检查记录，可在设置中重新检查');
        }
        return;
      }
      if (!_same(generation)) return;
      if (!_record.shouldCheck(_now())) {
        state = const StartupUpdateState();
        return;
      }
      final release = await repository.check(app);
      if (_same(generation)) await _accept(app, release, generation);
    } catch (_) {
      if (_same(generation)) {
        state = StartupUpdateState(
          notice: _record.forceRequired ? '版本检查失败，请稍后重试' : '',
        );
      }
    }
  }

  Future<void> refresh() async {
    if (!_current || state.busy) return;
    final generation = ++_generation;
    final previous = state.offer;
    state = StartupUpdateState(busy: true, offer: previous);
    try {
      final app = await source.read();
      if (!_same(generation)) return;
      final release = await repository.check(app);
      if (_same(generation)) await _accept(app, release, generation);
    } catch (_) {
      if (_same(generation)) {
        state = StartupUpdateState(offer: previous, notice: '版本检查失败，请稍后重试');
      }
    }
  }

  /// Manual check and startup use the same persisted facts. A newer manual
  /// response supersedes an older in-flight startup response.
  Future<void> acceptManual(InstalledApp app, AppUpdateRelease release) async {
    if (!_current) return;
    if (identical(_lastAccepted, release)) return;
    final generation = ++_generation;
    await _accept(app, release, generation);
  }

  Future<void> _accept(
    InstalledApp app,
    AppUpdateRelease release,
    int generation,
  ) async {
    _validate(app, release);
    if (!_same(generation)) return;
    _lastAccepted = release;
    final record = StartupUpdateRecord(
      lastSuccessDate: StartupUpdateRecord.day(_now()),
      forceRequired: release.hasUpdate && release.forceUpdate,
    );
    _record = record;
    final offer = release.hasUpdate ? StartupUpdateOffer(app, release) : null;
    // Keep force response visible even if local persistence fails.
    state = StartupUpdateState(busy: true, offer: offer);
    if (!_same(generation)) return;
    try {
      await store.write(app, record);
      if (_same(generation)) state = StartupUpdateState(offer: state.offer);
    } catch (_) {
      if (_same(generation)) {
        state = StartupUpdateState(
          offer: state.offer,
          notice: '更新检查记录未保存，下次启动会重新检查',
        );
      }
    }
  }

  void _validate(InstalledApp app, AppUpdateRelease release) {
    if (!app.valid ||
        release.packageName != app.packageName ||
        (release.hasUpdate &&
            (release.versionName.trim().isEmpty ||
                (release.versionCode != null && release.versionCode! <= 0)))) {
      throw const FormatException('Invalid update identity');
    }
  }

  void dismiss() {
    if (!_current || state.offer?.release.forceUpdate == true) return;
    state = StartupUpdateState(busy: state.busy);
  }

  String takeNotice() {
    if (!_current) return '';
    final notice = state.notice;
    if (notice.isNotEmpty) {
      state = StartupUpdateState(busy: state.busy, offer: state.offer);
    }
    return notice;
  }

  @override
  void dispose() {
    ++_generation;
    super.dispose();
  }
}
