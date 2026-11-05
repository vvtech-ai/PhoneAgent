import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/apple_cancellation_outbox_provider.dart';
import 'package:phone_agent/app/business_providers.dart';
import 'package:phone_agent/app/commerce_providers.dart';
import 'package:phone_agent/features/commerce/domain/apple_cancellation_outbox.dart';
import 'package:phone_agent/features/commerce/presentation/controller/ios_payment_runtime.dart';
import 'apple_cancel_startup_regression_test.dart'
    show MemoryCancelStore, StartupCancelRepo;
import 'ios_payment_wait_test.dart' show MemoryAttemptStore;
import 'ios_repeat_purchase_test.dart' show AppleLauncher;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() => debugDefaultTargetPlatformOverride = null);
  test(
    'Android keeps its original launcher and never reads iOS storage or cancellation owner',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final native = AppleLauncher();
      final container = ProviderContainer(
        overrides: [
          loginEpochProvider.overrideWithValue(1),
          commerceRepositoryProvider.overrideWithValue(StartupCancelRepo()),
          commerceDiagnosticsProvider.overrideWithValue(null),
          paymentLauncherProvider.overrideWithValue(native),
          appleCancellationOutboxProvider.overrideWith(
            (_) => throw StateError('iOS owner accessed on Android'),
          ),
          applePaymentAttemptStoreProvider.overrideWith(
            (_) => throw StateError('iOS storage accessed on Android'),
          ),
        ],
      );
      final subscription = container.listen(
        purchaseControllerProvider,
        (_, __) {},
      );
      final controller = container.read(purchaseControllerProvider.notifier);
      expect(controller.launcher, same(native));
      expect(controller.paymentChannel, 'ALIPAY');
      expect(container.read(iosPaymentRuntimeProvider), isNull);
      await Future<void>.delayed(Duration.zero);
      subscription.close();
      container.dispose();
    },
  );

  test(
    'iOS injects the account runtime and the production wait boundary',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final native = AppleLauncher();
      final repo = StartupCancelRepo();
      final container = ProviderContainer(
        overrides: [
          loginEpochProvider.overrideWithValue(1),
          commerceRepositoryProvider.overrideWithValue(repo),
          commerceDiagnosticsProvider.overrideWithValue(null),
          paymentLauncherProvider.overrideWithValue(native),
          appleCancellationOutboxProvider.overrideWithValue(
            AppleCancellationOutbox(
              MemoryCancelStore(),
              scope: 'A',
              isCurrent: () => true,
            ),
          ),
          applePaymentAttemptStoreProvider.overrideWithValue(
            MemoryAttemptStore(),
          ),
        ],
      );
      final subscription = container.listen(
        purchaseControllerProvider,
        (_, __) {},
      );
      final controller = container.read(purchaseControllerProvider.notifier);
      expect(controller.launcher, isA<IosPaymentRuntime>());
      expect((controller.launcher as IosPaymentRuntime).inner, same(native));
      expect(
        (controller.launcher as IosPaymentRuntime).waitLimit,
        const Duration(seconds: 30),
      );
      await Future<void>.delayed(Duration.zero);
      subscription.close();
      container.dispose();
    },
  );
}
