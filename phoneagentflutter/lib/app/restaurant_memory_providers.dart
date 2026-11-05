import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/auth/presentation/controller/auth_providers.dart';
import '../features/conversation/data/context/secure_restaurant_memory_asked.dart';
import '../features/conversation/domain/context/restaurant_contact_memory_offer.dart';
import 'business_providers.dart';

final restaurantMemoryAskedStoreProvider =
    Provider.autoDispose<RestaurantMemoryAskedStore>((ref) {
      ref.watch(loginEpochProvider);
      final account = ref
          .read(sessionControllerProvider.notifier)
          .credentials
          ?.accountId;
      return SecureRestaurantMemoryAsked(account ?? '');
    }, dependencies: [loginEpochProvider, sessionControllerProvider]);
final restaurantContactMemoryOfferProvider =
    Provider.autoDispose<RestaurantContactMemoryOffer>((ref) {
      ref.keepAlive();
      final epoch = ref.watch(loginEpochProvider);
      var active = true;
      final offer = RestaurantContactMemoryOffer(
        ref.watch(restaurantMemoryAskedStoreProvider),
        () => active && ref.read(loginEpochProvider) == epoch,
      );
      ref.onDispose(() {
        active = false;
        offer.close();
      });
      return offer;
    }, dependencies: [loginEpochProvider, restaurantMemoryAskedStoreProvider]);
