import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/commerce/domain/commerce_order_history.dart';
import 'business_providers.dart';
import 'commerce_providers.dart';

final applePurchaseHistoryProvider = FutureProvider.autoDispose<bool>((
  ref,
) async {
  if (ref.watch(loginEpochProvider) == null) return false;
  ref.listen(purchaseControllerProvider, (before, after) {
    if (before?.busy == true && !after.busy) {
      ref.invalidateSelf();
    }
  });
  final repository = ref.watch(commerceRepositoryProvider);
  if (repository is! CommerceOrderHistory) return false;
  final page = await (repository as CommerceOrderHistory).orders(
    0,
    size: 1,
    channel: 'APPLE_IAP',
  );
  return page.items.any((order) => order.channel == 'APPLE_IAP');
});

final appleRestoreVisibleProvider = Provider.autoDispose<bool>((ref) {
  final epoch = ref.watch(loginEpochProvider);
  if (epoch == null || kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
    return false;
  }
  ref.watch(purchaseControllerProvider);
  final history = ref.watch(applePurchaseHistoryProvider);
  return ref.read(purchaseControllerProvider.notifier).hasOwnedAppleRecovery ||
      (!history.isLoading && !history.hasError && history.valueOrNull == true);
});
