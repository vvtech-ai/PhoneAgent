import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/translation_location.dart';

class TranslationLocationController
    extends StateNotifier<TranslationLocationState> {
  TranslationLocationController(
    this.source,
    this.store, {
    int Function()? now,
    this.readAndroidPermission,
  }) : _now = now ?? (() => DateTime.now().millisecondsSinceEpoch),
       super(const TranslationLocationState());
  final Future<TranslationLocationStatus> Function()? readAndroidPermission;
  bool get androidNativeParity => readAndroidPermission != null;
  final TranslationLocationSource source;
  final TranslationLocationStore store;
  final int Function() _now;
  int _generation = 0;
  bool _loaded = false;
  Future<void>? _loading;
  bool _settingsOpen = false, _checkingPermission = false;
  bool _awaitingSettingsReturn = false;

  TranslationLocationState get snapshot => state;

  Future<void> load() {
    if (_loading != null) return _loading!;
    if (!mounted || _loaded || state.busy) return Future.value();
    return _loading = _load();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    state = const TranslationLocationState(
      status: TranslationLocationStatus.loading,
    );
    try {
      final trusted = await Future.sync(store.read);
      if (!_current(generation)) return;
      _loaded = true;
      state = TranslationLocationState(
        status: trusted == null
            ? TranslationLocationStatus.idle
            : TranslationLocationStatus.resolved,
        trusted: trusted,
        cached: trusted != null,
      );
    } catch (_) {
      if (_current(generation)) {
        state = const TranslationLocationState(error: '读取位置缓存失败，可重试或重新获取');
      }
    } finally {
      _loading = null;
    }
  }

  Future<void> refreshAfterPermission() async {
    await load();
    if (mounted) await locate();
  }

  Future<void> locate() async {
    if (!mounted || state.busy || _settingsOpen) return;
    final generation = ++_generation;
    final previous = state.trusted;
    state = TranslationLocationState(
      status: previous == null
          ? TranslationLocationStatus.locating
          : TranslationLocationStatus.resolved,
      refreshing: previous != null,
      trusted: previous,
      cached: previous != null,
    );
    try {
      final result = await source.locate();
      if (!_current(generation)) return;
      if (result.status != TranslationLocationStatus.resolved) {
        state = TranslationLocationState(
          status: previous == null
              ? result.status
              : TranslationLocationStatus.resolved,
          trusted: previous,
          cached: previous != null,
        );
        return;
      }
      final trusted = TrustedTranslationLocation(
        result.countryIso ?? '',
        _now(),
      );
      // Keep single-flight until persistence finishes. Never store coordinates.
      try {
        await store.write(trusted);
        if (!_current(generation)) return;
        _loaded = true;
        state = TranslationLocationState(
          status: TranslationLocationStatus.resolved,
          trusted: trusted,
        );
      } catch (_) {
        if (_current(generation)) {
          state = TranslationLocationState(
            status: TranslationLocationStatus.resolved,
            trusted: trusted,
            error: '当前位置已获取，但缓存保存失败；重新进入后可能需要再次获取',
          );
        }
      }
    } catch (_) {
      if (_current(generation)) {
        state = TranslationLocationState(
          status: previous == null
              ? TranslationLocationStatus.failed
              : TranslationLocationStatus.resolved,
          trusted: previous,
          cached: previous != null,
        );
      }
    }
  }

  /// Android country-card action checks permission without requesting it first.
  Future<void> requestLocation() async {
    final read = readAndroidPermission;
    if (read == null) return locate();
    if (!mounted ||
        state.busy ||
        _settingsOpen ||
        _checkingPermission ||
        _awaitingSettingsReturn) {
      return;
    }
    _checkingPermission = true;
    final generation = _generation;
    try {
      final permission = await read().timeout(const Duration(seconds: 3));
      if (!_current(generation)) return;
      if (permission == TranslationLocationStatus.blocked) {
        await openSettings();
      } else {
        await locate();
      }
    } catch (_) {
      if (_current(generation)) {
        state = TranslationLocationState(
          status: TranslationLocationStatus.failed,
          trusted: state.trusted,
          cached: state.cached,
        );
      }
    } finally {
      _checkingPermission = false;
    }
  }

  Future<void> resumeAfterSettings() async {
    final read = readAndroidPermission;
    if (read == null ||
        !mounted ||
        !_awaitingSettingsReturn ||
        _settingsOpen ||
        _checkingPermission) {
      return;
    }
    _awaitingSettingsReturn = false;
    _checkingPermission = true;
    final generation = _generation;
    try {
      final permission = await read().timeout(const Duration(seconds: 3));
      if (!_current(generation)) return;
      if (permission == TranslationLocationStatus.resolved) {
        await locate();
      } else {
        state = TranslationLocationState(
          status: state.trusted == null
              ? permission
              : TranslationLocationStatus.resolved,
          trusted: state.trusted,
          cached: state.trusted != null,
        );
      }
    } catch (_) {
      if (_current(generation)) {
        state = TranslationLocationState(
          status: TranslationLocationStatus.failed,
          trusted: state.trusted,
          cached: state.cached,
        );
      }
    } finally {
      _checkingPermission = false;
    }
  }

  Future<void> openSettings() async {
    if (!mounted || state.busy || _settingsOpen || _awaitingSettingsReturn) {
      return;
    }
    _settingsOpen = true;
    _awaitingSettingsReturn = androidNativeParity;
    final generation = _generation;
    try {
      await source.openSettings();
      if (_current(generation) && !androidNativeParity) {
        state = TranslationLocationState(
          status: TranslationLocationStatus.idle,
          trusted: state.trusted,
          cached: state.cached,
          error: '从系统设置返回后，请点击获取重新检查权限',
        );
      }
    } catch (_) {
      _awaitingSettingsReturn = false;
      if (_current(generation)) {
        state = TranslationLocationState(
          status: TranslationLocationStatus.blocked,
          trusted: state.trusted,
          cached: state.cached,
          error: '无法打开设置，请手动检查本应用的定位权限',
        );
      }
    } finally {
      _settingsOpen = false;
    }
  }

  bool _current(int generation) => mounted && generation == _generation;
  void cancel() {
    if (!mounted) return;
    _awaitingSettingsReturn = false;
    _generation++;
    unawaited(source.cancel().catchError((Object _) {}));
    if (state.busy) {
      state = TranslationLocationState(
        status: state.trusted == null
            ? TranslationLocationStatus.idle
            : TranslationLocationStatus.resolved,
        trusted: state.trusted,
        cached: state.trusted != null,
      );
    }
  }

  @override
  void dispose() {
    _generation++;
    unawaited(source.cancel().catchError((Object _) {}));
    super.dispose();
  }
}
