import 'dial_permission_store.dart';

enum DialPermissionGrant { granted, denied, blocked, unavailable }

abstract interface class DialPermissionPort {
  bool get supportsCallLog;
  Future<DialPermissionGrant> location({bool request = false});
  Future<DialPermissionGrant> callLog({bool request = false});
  Future<void> openSettings();
}

/// App prompt memory only; it is never proof of OS authorization.
class DialPermissionMemory {
  DialPermissionMemory({DialPermissionStore? store}) : _store = store {
    ready = _restore();
  }
  final DialPermissionStore? _store;
  late final Future<void> ready;
  Future<void> _pending = Future<void>.value();
  Future<void> get flushed => _pending;
  bool _locationShown = false,
      _locationRequested = false,
      _callLogRequested = false;
  bool get locationShown => _locationShown;
  set locationShown(bool value) {
    _locationShown = value;
    _persist();
  }

  bool get locationRequested => _locationRequested;
  set locationRequested(bool value) {
    _locationRequested = value;
    _persist();
  }

  bool get callLogRequested => _callLogRequested;
  set callLogRequested(bool value) {
    _callLogRequested = value;
    _persist();
  }

  int generation = 0;
  Future<void> _restore() async {
    final owner = generation;
    try {
      final flags = await _store?.read();
      if (flags == null || generation != owner) return;
      _locationShown = flags.locationShown;
      _locationRequested = flags.locationRequested;
      _callLogRequested = flags.callLogRequested;
    } catch (_) {
      // Prompt history never replaces a real system permission check.
    }
  }

  void _persist() {
    final store = _store;
    if (store == null) return;
    final flags = (
      locationShown: _locationShown,
      locationRequested: _locationRequested,
      callLogRequested: _callLogRequested,
    );
    // Register immediately in the store's shared queue so a new owner reads
    // after these writes, even when it replaces this memory in the same turn.
    _pending = store.write(flags).catchError((Object _) {});
  }

  void resetLocation() {
    generation++;
    _locationShown = false;
    _locationRequested = false;
    _persist();
    // v65 explicitly leaves the one-shot CallLog marker untouched.
  }
}

enum DialPermissionStage {
  idle,
  checking,
  request,
  blocked,
  requesting,
  settings,
  ready,
  failed,
}

class DialPermissionState {
  const DialPermissionState(this.stage, {this.message = ''});
  final DialPermissionStage stage;
  final String message;
  bool get busy =>
      stage == DialPermissionStage.checking ||
      stage == DialPermissionStage.requesting;
  bool get hasDialog =>
      stage == DialPermissionStage.request ||
      stage == DialPermissionStage.blocked ||
      stage == DialPermissionStage.failed;
}
