import 'secure_app_call_record_repository.dart';

/// Exercises the real codec/serialization without secure storage or an account.
class PreviewAppCallRecordStore {
  String? _raw;
  bool failWrite = false;
  late final repository = SecureAppCallRecordRepository(
    environment: 'MOCK',
    apiBase: 'https://synthetic.invalid/',
    accountId: 'preview',
    isCurrent: () => true,
    read: (_) async => _raw,
    write: (_, value) async {
      if (failWrite) throw StateError('Synthetic write failure');
      _raw = value;
    },
  );
}
