import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/context/agent_context_builder.dart';
import 'package:phone_agent/features/conversation/domain/context/restaurant_contact_memory_offer.dart';
import 'agent_context_builder_test.dart' show FakeClock, FakePermissions;

class AskedStore implements RestaurantMemoryAskedStore {
  bool asked = false, fail = false;
  int writes = 0;
  Completer<bool>? pending;
  @override
  Future<bool> read() async => pending == null ? asked : pending!.future;
  @override
  Future<void> markAsked() async {
    writes++;
    if (fail) throw StateError('synthetic storage failure');
    asked = true;
  }
}

void main() {
  for (final persisted in [false, true]) {
    test(
      'first task waits for persisted account offer flag: $persisted',
      () async {
        final store = AskedStore()..pending = Completer<bool>();
        final offer = RestaurantContactMemoryOffer(store, () => true);
        final builder = AgentContextBuilder(
          location: () async => const {},
          clock: FakeClock(),
          permissions: FakePermissions(),
          memoryContext: offer.context,
        );
        var completed = false;
        final context = builder.prepare().then((value) {
          completed = true;
          return value;
        });
        await Future<void>.delayed(Duration.zero);
        expect(completed, isFalse);
        store.pending!.complete(persisted);
        expect(
          await context,
          containsPair('restaurantContactMemoryAsked', persisted),
        );
        expect(store.writes, 0);
      },
    );
  }
  test(
    'per-turn context preserves clock and permissions; only offer flag is stored',
    () async {
      final store = AskedStore();
      final offer = RestaurantContactMemoryOffer(store, () => true);
      final builder = AgentContextBuilder(
        location: () async => const {},
        clock: FakeClock(),
        permissions: FakePermissions(),
        memoryContext: offer.context,
      );
      expect(
        await builder.prepare(),
        containsPair('restaurantContactMemoryAsked', false),
      );
      expect(await offer.shown(() => true), isTrue);
      final next = await builder.prepare();
      expect(next, containsPair('restaurantContactMemoryAsked', true));
      expect(next, contains('currentTime'));
      expect(next, contains('permissionStatus'));
      expect(next.containsKey('defaultReservationContact'), isFalse);
      expect(next.containsKey('identity'), isFalse);
      expect(await offer.shown(() => true), isTrue);
      expect(store.writes, 1);
      final restored = RestaurantContactMemoryOffer(store, () => true);
      expect(
        await restored.context(),
        containsPair('restaurantContactMemoryAsked', true),
      );
      expect(await restored.shown(() => true), isTrue);
      expect(store.writes, 1);
    },
  );
  test('unseen or exited pending offer never writes', () async {
    final store = AskedStore()..pending = Completer();
    var visible = false;
    final offer = RestaurantContactMemoryOffer(store, () => true);
    expect(await offer.shown(() => visible), isFalse);
    visible = true;
    final pending = offer.shown(() => visible);
    visible = false;
    store.pending!.complete(false);
    expect(await pending, isFalse);
    expect(store.writes, 0);
  });
  test('late old-account read cannot mark new account', () async {
    final old = AskedStore()..pending = Completer();
    var current = true;
    final offer = RestaurantContactMemoryOffer(old, () => current);
    final pending = offer.shown(() => true);
    current = false;
    old.pending!.complete(false);
    expect(await pending, isFalse);
    expect(await offer.context(), isEmpty);
    final next = AskedStore();
    expect(
      await RestaurantContactMemoryOffer(next, () => true).context(),
      containsPair('restaurantContactMemoryAsked', false),
    );
    expect(old.writes, 0);
    expect(next.writes, 0);
  });
  test(
    'storage failure does not fabricate success and a later display retries',
    () async {
      final store = AskedStore()..fail = true;
      final offer = RestaurantContactMemoryOffer(store, () => true);
      expect(await offer.shown(() => true), isFalse);
      expect(
        await offer.context(),
        containsPair('restaurantContactMemoryAsked', false),
      );
      store.fail = false;
      expect(await offer.shown(() => true), isTrue);
      expect(
        await offer.context(),
        containsPair('restaurantContactMemoryAsked', true),
      );
      expect(store.writes, 2);
    },
  );
  test(
    'duplicate displayed events share one write and context waits for it',
    () async {
      final store = AskedStore()..pending = Completer();
      final offer = RestaurantContactMemoryOffer(store, () => true);
      final first = offer.shown(() => true),
          duplicate = offer.shown(() => true);
      final context = offer.context();
      store.pending!.complete(false);
      expect(await first, isTrue);
      expect(await duplicate, isTrue);
      expect(await context, containsPair('restaurantContactMemoryAsked', true));
      expect(store.writes, 1);
      offer.close();
      expect(await offer.context(), isEmpty);
    },
  );
}
