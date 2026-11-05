import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/dialer/data/device_call_log_channel.dart';
import '../features/dialer/data/dial_recent_sources.dart';
import '../features/dialer/domain/dial_recent_source.dart';
import '../features/dialer/presentation/controller/dial_recent_controller.dart';
import 'business_providers.dart';
import 'app_call_record_providers.dart';
import '../features/dialer/data/app_dial_recent_source.dart';

final systemDialRecentSourceProvider = Provider<DialRecentCallSource>(
  (ref) => const DeviceCallLogChannel(),
);
final appDialRecentSourceProvider = Provider<DialRecentCallSource>((ref) {
  final repository = ref.watch(appCallRecordRepositoryProvider);
  return repository == null
      ? const UnavailableDialRecentSource(DialRecentAccess.notConnected)
      : AppDialRecentSource(repository);
});
final dialRecentProvider =
    StateNotifierProvider.autoDispose<DialRecentController, DialRecentState>((
      ref,
    ) {
      ref.watch(loginEpochProvider);
      final controller = DialRecentController(
        ref.watch(systemDialRecentSourceProvider),
        ref.watch(appDialRecentSourceProvider),
      );
      controller.load();
      return controller;
    });
