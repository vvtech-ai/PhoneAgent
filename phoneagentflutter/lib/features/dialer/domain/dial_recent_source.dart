import 'dial_recent_call.dart';

enum DialRecentAccess { ready, denied, unsupported, notConnected, failed }

class DialRecentSnapshot {
  const DialRecentSnapshot(this.access, [this.records = const []]);
  final DialRecentAccess access;
  final List<DialRecentCall> records;
}

abstract interface class DialRecentCallSource {
  /// Read only: this boundary never requests permission or starts a call.
  Future<DialRecentSnapshot> load();
}

abstract interface class ObservableDialRecentSource
    implements DialRecentCallSource {
  Stream<void> get changes;
}
