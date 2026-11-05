import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/auth/presentation/controller/auth_providers.dart';
import '../features/dialer/domain/app_call_record_repository.dart';
import '../features/dialer/domain/app_dial_history_recorder.dart';
import '../features/dialer/data/secure_app_call_record_repository.dart';
import '../features/dialer/data/device_legacy_call_records.dart';
import 'app_providers.dart';
import 'business_providers.dart';

final appCallRecordRepositoryProvider = Provider<AppCallRecordRepository?>((
  ref,
) {
  ref.watch(loginEpochProvider);
  final session = ref.watch(sessionControllerProvider.notifier);
  final owner = session.credentials;
  final config = ref.watch(appConfigProvider);
  if (owner == null ||
      config.environment == null ||
      config.apiBaseUri == null) {
    return null;
  }
  var active = true;
  final repository = SecureAppCallRecordRepository(
    environment: config.environment!.name,
    apiBase: config.apiBaseUri.toString(),
    accountId: owner.accountId,
    isCurrent: () => active && owner.sameLogin(session.credentials),
    readLegacy: DeviceLegacyCallRecords.eligible(config)
        ? DeviceLegacyCallRecords(
            config: config,
            accountId: owner.accountId,
          ).read
        : null,
  );
  ref.onDispose(() {
    active = false;
    repository.close();
  });
  return repository;
});

final appDialHistoryRecorderProvider = Provider<AppDialHistoryRecorder?>((ref) {
  final repository = ref.watch(appCallRecordRepositoryProvider);
  return repository == null ? null : AppDialHistoryRecorder(repository);
});
