import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/apple_transaction_providers.dart';
import 'package:phone_agent/app/app_providers.dart';
import 'package:phone_agent/app/business_providers.dart';
import 'package:phone_agent/app/online_entry_providers.dart';
import 'package:phone_agent/core/config/app_config.dart';
import 'package:phone_agent/features/settings/domain/network_availability.dart';
import 'package:phone_agent/features/settings/domain/network_availability_events.dart';

class Network implements NetworkAvailabilityEvents {
  final events = StreamController<NetworkAvailability>.broadcast();
  @override
  Stream<NetworkAvailability> watch() => events.stream;
}

final epoch = StateProvider<int?>((_) => null);
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'actual application coordinator survives A B A and signed-out provider transitions',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      FlutterSecureStorage.setMockInitialValues({});
      final network = Network();
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        const MethodChannel('phone_agent/commerce_payment'),
        (call) async => switch (call.method) {
          'available' => true,
          'restore' => [],
          _ => null,
        },
      );
      messenger.setMockMethodCallHandler(
        const MethodChannel('phone_agent/commerce_transactions'),
        (_) async => null,
      );
      final container = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(
            AppConfig.parse(
              environment: 'test',
              apiBaseUrl: 'https://example.test',
            ),
          ),
          loginEpochProvider.overrideWith((ref) => ref.watch(epoch)),
          networkAvailabilityEventsProvider.overrideWithValue(network),
        ],
      );
      try {
        final worker = container.read(appleTransactionCoordinatorProvider);
        expect(worker, isNotNull);
        for (final next in <int?>[1, 2, 3, null, 4]) {
          container.read(epoch.notifier).state = next;
          expect(container.read(loginEpochProvider), next);
          expect(
            identical(
              worker,
              container.read(appleTransactionCoordinatorProvider),
            ),
            true,
          );
        }
        await Future<void>.delayed(const Duration(milliseconds: 10));
      } finally {
        container.dispose();
        await network.events.close();
        messenger.setMockMethodCallHandler(
          const MethodChannel('phone_agent/commerce_payment'),
          null,
        );
        messenger.setMockMethodCallHandler(
          const MethodChannel('phone_agent/commerce_transactions'),
          null,
        );
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );
}
