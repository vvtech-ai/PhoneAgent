import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/settings/data/device_network_availability.dart';
import '../features/settings/domain/network_availability.dart';
import '../features/settings/domain/network_availability_events.dart';
import '../features/settings/presentation/controller/online_entry_controller.dart';
import 'developer_network_providers.dart';

final networkAvailabilitySourceProvider = Provider<NetworkAvailabilitySource>(
  (_) =>
      !kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS)
      ? const DeviceNetworkAvailability()
      : const UnknownNetworkAvailability(),
);

final networkAvailabilityEventsProvider = Provider<NetworkAvailabilityEvents>((
  ref,
) {
  final source = ref.watch(networkAvailabilitySourceProvider);
  return source is NetworkAvailabilityEvents
      ? source as NetworkAvailabilityEvents
      : const NoNetworkAvailabilityEvents();
});

final onlineEntryControllerProvider = Provider<OnlineEntryController>(
  (ref) {
    final controller = OnlineEntryController(
      ref.watch(networkAvailabilitySourceProvider),
      () => ref.read(developerNetworkModeProvider).blocksOnlineEntry,
    );
    ref.onDispose(controller.close);
    return controller;
  },
  dependencies: [
    networkAvailabilitySourceProvider,
    developerNetworkModeProvider,
  ],
);
