import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/agent_context_providers.dart';
import 'package:phone_agent/app/agent_location_providers.dart';
import 'package:phone_agent/app/business_providers.dart';
import 'package:phone_agent/features/conversation/domain/context/agent_location.dart';
import 'agent_context_builder_test.dart' show FakeClock, FakePermissions;
import 'package:phone_agent/app/restaurant_memory_providers.dart';
import 'restaurant_contact_memory_offer_test.dart' show AskedStore;

class _Location implements AgentLocationSource {
  @override
  Future<AgentLocation?> read() async => null;
  @override
  Future<void> cancel() async {}
}

void main() {
  test(
    'login replacement closes old builder and new generation still reads',
    () async {
      var epoch = 1;
      final stores = <int, AskedStore>{};
      final container = ProviderContainer(
        overrides: [
          loginEpochProvider.overrideWith((_) => epoch),
          restaurantMemoryAskedStoreProvider.overrideWith(
            (ref) => stores.putIfAbsent(
              ref.watch(loginEpochProvider)!,
              AskedStore.new,
            ),
          ),
          agentClockSourceProvider.overrideWithValue(FakeClock()),
          conversationPermissionSourceProvider.overrideWithValue(
            FakePermissions(),
          ),
          agentLocationSourceProvider.overrideWithValue(_Location()),
        ],
      );
      addTearDown(container.dispose);
      final sub = container.listen(agentContextBuilderProvider, (_, __) {});
      addTearDown(sub.close);
      final old = container.read(agentContextBuilderProvider);
      expect(await old.prepare(), contains('currentTime'));
      expect(
        await old.prepare(),
        containsPair('restaurantContactMemoryAsked', false),
      );
      final offer = container.read(restaurantContactMemoryOfferProvider);
      expect(await offer.shown(() => true), isTrue);
      expect(
        await old.prepare(),
        containsPair('restaurantContactMemoryAsked', true),
      );
      epoch++;
      container.invalidate(loginEpochProvider);
      final current = container.read(agentContextBuilderProvider);
      expect(identical(current, old), isFalse);
      expect(await old.prepare(), isEmpty);
      expect(await current.prepare(), contains('permissionStatus'));
      expect(
        await current.prepare(),
        containsPair('restaurantContactMemoryAsked', false),
      );
      expect(await offer.shown(() => true), isFalse);
      expect(stores[1]!.writes, 1);
      expect(stores[2]!.writes, 0);
    },
  );
}
