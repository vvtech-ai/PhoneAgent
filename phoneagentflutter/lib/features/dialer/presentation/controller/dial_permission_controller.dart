import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/dial_permission.dart';

class DialPermissionController extends StateNotifier<DialPermissionState> {
  DialPermissionController({
    required this.port,
    required this.memory,
    required this.setTranslation,
    required this.refreshRegion,
    required this.refreshRecent,
    this.androidNativeParity = false,
    bool Function()? simulatedLocation,
  }) : simulatedLocation = simulatedLocation ?? _noSimulation,
       _owner = memory.generation,
       super(const DialPermissionState(DialPermissionStage.idle));
  static bool _noSimulation() => false;
  final bool Function() simulatedLocation;
  final bool androidNativeParity;
  final DialPermissionPort port;
  final DialPermissionMemory memory;
  final void Function(bool) setTranslation;
  final void Function() refreshRegion, refreshRecent;
  final int _owner;
  bool _enableAfterGrant = false, _started = false;
  bool get _current => mounted && memory.generation == _owner;
  DialPermissionState get snapshot => state;

  Future<void> start({required bool translationEnabled}) async {
    if (!_current || _started) return;
    _started = true;
    await _check(initial: true, enabled: translationEnabled);
  }

  Future<void> toggle(bool enabled) async {
    if (!_current ||
        state.busy ||
        state.hasDialog ||
        state.stage == DialPermissionStage.settings) {
      return;
    }
    if (!enabled) {
      setTranslation(false);
      return;
    }
    await _check(initial: false, enabled: true);
  }

  Future<void> _check({required bool initial, required bool enabled}) async {
    _enableAfterGrant = enabled;
    state = const DialPermissionState(DialPermissionStage.checking);
    try {
      await memory.ready;
      if (!_current) return;
      if (simulatedLocation()) {
        if (!initial) setTranslation(enabled);
        await _complete();
        return;
      }
      final grant = await port.location().timeout(const Duration(seconds: 3));
      if (!_current) return;
      if (grant == DialPermissionGrant.granted) {
        _enableAfterGrant = !initial && enabled;
        await _granted();
      } else if (grant == DialPermissionGrant.unavailable) {
        if (!initial) setTranslation(false);
        state = const DialPermissionState(
          DialPermissionStage.ready,
          message: '当前环境无法检查位置权限，请在手机上验证',
        );
      } else if ((!androidNativeParity &&
              grant == DialPermissionGrant.blocked) ||
          !initial ||
          !memory.locationShown) {
        memory.locationShown = true;
        _enableAfterGrant = enabled;
        state = DialPermissionState(
          androidNativeParity && initial
              ? DialPermissionStage.request
              : grant == DialPermissionGrant.blocked
              ? DialPermissionStage.blocked
              : DialPermissionStage.request,
        );
      } else {
        await _complete();
      }
    } catch (_) {
      _failed();
    }
  }

  Future<void> confirm() async {
    if (!_current) return;
    if (state.stage == DialPermissionStage.blocked) {
      state = const DialPermissionState(DialPermissionStage.settings);
      try {
        await port.openSettings();
      } catch (_) {
        _failed();
      }
      return;
    }
    if (state.stage != DialPermissionStage.request) return;
    memory.locationRequested = true;
    state = const DialPermissionState(DialPermissionStage.requesting);
    try {
      final grant = await port
          .location(request: true)
          .timeout(const Duration(seconds: 90));
      if (!_current) return;
      if (grant == DialPermissionGrant.granted) {
        await _granted();
      } else {
        setTranslation(false);
        _enableAfterGrant = false;
        await _complete();
      }
    } catch (_) {
      _failed();
    }
  }

  Future<void> resume() async {
    if (!_current || state.stage != DialPermissionStage.settings) return;
    state = const DialPermissionState(DialPermissionStage.checking);
    try {
      final grant = await port.location().timeout(const Duration(seconds: 3));
      if (!_current) return;
      if (grant == DialPermissionGrant.granted) {
        await _granted();
      } else {
        setTranslation(false);
        _enableAfterGrant = false;
        await _complete();
      }
    } catch (_) {
      _failed();
    }
  }

  Future<void> cancel() async {
    if (!_current ||
        state.busy ||
        (!state.hasDialog && state.stage != DialPermissionStage.settings)) {
      return;
    }
    setTranslation(false);
    _enableAfterGrant = false;
    await _complete();
  }

  Future<void> retry() async {
    if (!_current || state.stage != DialPermissionStage.failed) return;
    await _check(initial: false, enabled: _enableAfterGrant);
  }

  Future<void> _granted() async {
    if (!_current) return;
    refreshRegion();
    if (_enableAfterGrant) setTranslation(true);
    _enableAfterGrant = false;
    await _complete();
  }

  Future<void> _complete() async {
    if (!_current) return;
    state = const DialPermissionState(DialPermissionStage.checking);
    try {
      if (port.supportsCallLog) {
        var grant = await port.callLog().timeout(const Duration(seconds: 3));
        if (!_current) return;
        if (grant != DialPermissionGrant.granted &&
            grant != DialPermissionGrant.unavailable &&
            !memory.callLogRequested) {
          memory.callLogRequested = true;
          grant = await port
              .callLog(request: true)
              .timeout(const Duration(seconds: 90));
          if (!_current) return;
        }
        if (grant == DialPermissionGrant.granted) refreshRecent();
      }
      if (_current) {
        state = const DialPermissionState(DialPermissionStage.ready);
      }
    } catch (_) {
      if (_current) {
        state = const DialPermissionState(
          DialPermissionStage.ready,
          message: '通话记录权限检查失败，可继续普通拨号',
        );
      }
    }
  }

  void _failed() {
    if (_current) {
      state = const DialPermissionState(
        DialPermissionStage.failed,
        message: '位置权限检查失败，可重试或继续普通拨号',
      );
    }
  }
}
