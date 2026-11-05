import 'dial_recent_call.dart';

/// Account-local dial metadata, not server history or media credentials.
abstract interface class AppCallRecordRepository {
  Future<List<DialRecentCall>> load();
  Future<void> append(DialRecentCall record);
  Future<void> clear();
  Stream<void> get changes;
  void close();
}

class AppCallRecordFailure implements Exception {
  const AppCallRecordFailure(this.code);
  final String code;
  @override
  String toString() => 'AppCallRecordFailure($code)';
}
