import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/business_providers.dart';
import 'package:phone_agent/app/call_model_refresh_providers.dart';
import 'package:phone_agent/app/commerce_providers.dart';
import 'package:phone_agent/app/translation_directory_providers.dart';
import 'package:phone_agent/features/translation/domain/translation_directory.dart';
import 'fake_commerce_repository.dart';

void main() {
  test(
    'fulfilled membership invalidates cached account translation options once',
    () async {
      var reads = 0;
      var callRefreshes = 0;
      final repository = FakeCommerceRepository();
      final container = ProviderContainer(
        overrides: [
          callModelRefreshProvider.overrideWithValue(() async {
            callRefreshes++;
          }),
          loginEpochProvider.overrideWith((ref) => 1),
          commerceRepositoryProvider.overrideWithValue(repository),
          paymentLauncherProvider.overrideWithValue(FakePaymentLauncher()),
          translationDirectoryProvider.overrideWith((ref) async {
            reads++;
            return const TranslationDirectory(
              version: 1,
              models: [],
              countries: [],
              languages: [],
            );
          }),
        ],
      );
      addTearDown(container.dispose);
      final listening = container.listen(
        translationDirectoryProvider,
        (_, __) {},
      );
      addTearDown(listening.close);
      final purchaseListening = container.listen(
        purchaseControllerProvider,
        (_, __) {},
      );
      addTearDown(purchaseListening.close);
      await container.read(translationDirectoryProvider.future);
      final purchase = container.read(purchaseControllerProvider.notifier);
      await purchase.query('order-1');
      repository.current = sampleOrder(
        payment: 'SUCCEEDED',
        fulfillment: 'PROCESSING',
      );
      await purchase.query('order-1');
      await container.pump();
      expect(reads, 1);
      expect(callRefreshes, 0);
      repository.current = sampleOrder(
        payment: 'SUCCEEDED',
        fulfillment: 'SUCCEEDED',
      );
      await purchase.query('order-1');
      await container.pump();
      await container.read(translationDirectoryProvider.future);
      expect(reads, 2);
      expect(callRefreshes, 1);
      await purchase.query('order-1');
      await container.pump();
      expect(reads, 2);
      expect(callRefreshes, 1);
    },
  );
  test(
    'old account late purchase cannot invalidate new account options',
    () async {
      var reads = 0;
      var callRefreshes = 0;
      final epoch = StateProvider((ref) => 1);
      final repository = FakeCommerceRepository();
      final container = ProviderContainer(
        overrides: [
          callModelRefreshProvider.overrideWithValue(() async {
            callRefreshes++;
          }),
          loginEpochProvider.overrideWith((ref) => ref.watch(epoch)),
          commerceRepositoryProvider.overrideWithValue(repository),
          paymentLauncherProvider.overrideWithValue(FakePaymentLauncher()),
          translationDirectoryProvider.overrideWith((ref) async {
            ref.watch(loginEpochProvider);
            reads++;
            return const TranslationDirectory(
              version: 1,
              models: [],
              countries: [],
              languages: [],
            );
          }),
        ],
      );
      addTearDown(container.dispose);
      final listening = container.listen(
        translationDirectoryProvider,
        (_, __) {},
      );
      addTearDown(listening.close);
      final purchaseListening = container.listen(
        purchaseControllerProvider,
        (_, __) {},
      );
      addTearDown(purchaseListening.close);
      await container.read(translationDirectoryProvider.future);
      final purchase = container.read(purchaseControllerProvider.notifier);
      repository.delayedOrder = Completer();
      final pending = purchase.query('order-1');
      container.read(epoch.notifier).state = 2;
      await container.pump();
      await container.read(translationDirectoryProvider.future);
      repository.delayedOrder!.complete(
        sampleOrder(payment: 'SUCCEEDED', fulfillment: 'SUCCEEDED'),
      );
      await pending;
      await container.pump();
      expect(reads, 2);
      expect(callRefreshes, 0);
    },
  );
}
