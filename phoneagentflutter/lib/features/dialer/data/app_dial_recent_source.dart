import '../domain/app_call_record_repository.dart';
import '../domain/dial_recent_call.dart';
import '../domain/dial_recent_source.dart';

class AppDialRecentSource implements ObservableDialRecentSource {
  AppDialRecentSource(this.repository);
  final AppCallRecordRepository repository;
  @override
  Stream<void> get changes => repository.changes;
  @override
  Future<DialRecentSnapshot> load() async {
    try {
      final rows = await repository.load();
      return DialRecentSnapshot(
        DialRecentAccess.ready,
        List.unmodifiable(
          rows.where((row) => row.kind == DialRecentKind.translation),
        ),
      );
    } catch (_) {
      return const DialRecentSnapshot(DialRecentAccess.failed);
    }
  }
}
