import 'package:test/test.dart';
import 'package:phone_agent/features/dialer/domain/app_call_record_repository.dart';
import 'package:phone_agent/features/dialer/domain/app_dial_history_recorder.dart';
import 'package:phone_agent/features/dialer/domain/dial_recent_call.dart';

void main() {
  test(
    'default handoff ID works on VM and JavaScript without injection',
    () async {
      final records = _Records();
      final recorder = AppDialHistoryRecorder(records);
      await recorder.systemHandoff('+12025550123', 'MOCK', 'US');
      await recorder.systemHandoff('+12025550123', 'MOCK', 'US');
      expect(records.values, hasLength(2));
      expect(records.values.map((r) => r.id).toSet(), hasLength(2));
      for (final record in records.values) {
        expect(record.id, matches(RegExp(r'^system-\d+-\d+$')));
        expect(record.phone, '+12025550123');
        expect(record.kind, DialRecentKind.normal);
        expect(record.source, DialRecentSource.app);
      }
    },
  );
}

class _Records implements AppCallRecordRepository {
  final values = <DialRecentCall>[];
  @override
  Future<void> append(DialRecentCall record) async => values.add(record);
  @override
  Future<List<DialRecentCall>> load() async => List.unmodifiable(values);
  @override
  Future<void> clear() async => values.clear();
  @override
  Stream<void> get changes => const Stream.empty();
  @override
  void close() {}
}
