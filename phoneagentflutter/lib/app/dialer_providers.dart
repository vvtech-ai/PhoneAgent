import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/dialer/data/system_dialer_channel.dart';
import '../features/dialer/domain/system_dialer.dart';
import '../features/dialer/presentation/controller/dialer_controller.dart';
import 'business_providers.dart';
import 'settings_providers.dart';
import 'app_call_record_providers.dart';

final systemDialerProvider = Provider<SystemDialer>(
  (ref) => const SystemDialerChannel(),
);
// Input survives closing the dial sheet, but not switching login ownership.
final dialerControllerProvider =
    StateNotifierProvider<DialerController, DialerState>((ref) {
      ref.watch(loginEpochProvider);
      return DialerController(
        ref.watch(systemDialerProvider),
        onOpened: ref.watch(appDialHistoryRecorderProvider)?.systemHandoff,
        onUnlockDeveloper: () =>
            ref.read(developerModeProvider.notifier).state = true,
      );
    });
