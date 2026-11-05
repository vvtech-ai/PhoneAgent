import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/business_providers.dart';
import 'package:phone_agent/app/clone_flow_providers.dart';
import 'package:phone_agent/app/clone_readiness_provider.dart';
import 'package:phone_agent/features/voice_clone/domain/clone_creation.dart';

class _Port implements CloneCreationPort {
  final pending = <Completer<List<CloneCreationModel>>>[];
  @override
  Future<List<CloneCreationModel>> models() {
    final result = Completer<List<CloneCreationModel>>();
    pending.add(result);
    return result.future;
  }

  @override
  Future<int> availablePoints() => throw StateError('unexpected wallet');
  @override
  Future<bool> hasValidRecording() => throw StateError('unexpected recording');
}

List<CloneCreationModel> rows(int price) => [
  CloneCreationModel(
    id: '4',
    name: 'A',
    pricePoints: price,
    currentReady: true,
  ),
  const CloneCreationModel(id: '7', name: 'B', pricePoints: 900),
];
void main() {
  test(
    'two model prices and readiness share one directory and never borrow another model price',
    () async {
      final port = _Port();
      final c = ProviderContainer(
        overrides: [
          loginEpochProvider.overrideWithValue(1),
          cloneCreationPortProvider.overrideWithValue(port),
        ],
      );
      addTearDown(c.dispose);
      final a = c.listen(cloneEntryPriceProvider('4'), (_, __) {});
      final b = c.listen(cloneEntryPriceProvider('7'), (_, __) {});
      final ready = c.listen(cloneReadinessProvider, (_, __) {});
      addTearDown(a.close);
      addTearDown(b.close);
      addTearDown(ready.close);
      expect(c.read(cloneEntryPriceProvider('4')), isNull);
      expect(port.pending, hasLength(1));
      port.pending.single.complete(rows(650));
      await c.read(cloneCatalogProvider.future);
      await Future<void>.delayed(Duration.zero);
      expect(c.read(cloneEntryPriceProvider('4')), 650);
      expect(c.read(cloneEntryPriceProvider('7')), 900);
      expect(c.read(cloneEntryPriceProvider('missing')), isNull);
      expect(c.read(cloneEntryPriceProvider(null)), isNull);
      expect(await c.read(cloneReadinessProvider.future), true);
      expect(port.pending, hasLength(1));
    },
  );
  test(
    'refresh and failure hide old price; explicit directory invalidation updates both facts',
    () async {
      final port = _Port();
      final c = ProviderContainer(
        overrides: [
          loginEpochProvider.overrideWithValue(1),
          cloneCreationPortProvider.overrideWithValue(port),
        ],
      );
      addTearDown(c.dispose);
      final sub = c.listen(cloneEntryPriceProvider('4'), (_, __) {});
      addTearDown(sub.close);
      port.pending.single.complete(rows(650));
      await c.read(cloneCatalogProvider.future);
      expect(c.read(cloneEntryPriceProvider('4')), 650);
      c.invalidate(cloneCatalogProvider);
      expect(c.read(cloneEntryPriceProvider('4')), isNull);
      final failed = c.read(cloneCatalogProvider.future);
      port.pending.last.completeError(StateError('synthetic'));
      await expectLater(failed, throwsStateError);
      expect(c.read(cloneEntryPriceProvider('4')), isNull);
      c.invalidate(cloneCatalogProvider);
      expect(c.read(cloneEntryPriceProvider('4')), isNull);
      port.pending.last.complete(rows(750));
      await c.read(cloneCatalogProvider.future);
      expect(c.read(cloneEntryPriceProvider('4')), 750);
      expect(port.pending, hasLength(3));
    },
  );
  test(
    'late old-account response never becomes current price; signout reads nothing',
    () async {
      final epoch = StateProvider<int?>((_) => 1);
      final port = _Port();
      final c = ProviderContainer(
        overrides: [
          loginEpochProvider.overrideWith((ref) => ref.watch(epoch)),
          cloneCreationPortProvider.overrideWithValue(port),
        ],
      );
      addTearDown(c.dispose);
      final sub = c.listen(cloneEntryPriceProvider('4'), (_, __) {});
      addTearDown(sub.close);
      final old = port.pending.single;
      c.read(epoch.notifier).state = 2;
      expect(c.read(cloneEntryPriceProvider('4')), isNull);
      final current = c.read(cloneCatalogProvider.future);
      old.complete(rows(650));
      port.pending.last.complete(rows(800));
      await current;
      expect(c.read(cloneEntryPriceProvider('4')), 800);
      c.read(epoch.notifier).state = null;
      expect(c.read(cloneEntryPriceProvider('4')), isNull);
      expect(port.pending, hasLength(2));
    },
  );
  test(
    'model selection changes price without a new request and page reentry reloads catalog',
    () async {
      final selected = StateProvider<String?>((_) => '4');
      final visible = Provider.autoDispose(
        (ref) => ref.watch(cloneEntryPriceProvider(ref.watch(selected))),
      );
      final port = _Port();
      final c = ProviderContainer(
        overrides: [
          loginEpochProvider.overrideWithValue(1),
          cloneCreationPortProvider.overrideWithValue(port),
        ],
      );
      addTearDown(c.dispose);
      final sub = c.listen(visible, (_, __) {});
      port.pending.single.complete(rows(650));
      await c.read(cloneCatalogProvider.future);
      expect(c.read(visible), 650);
      c.read(selected.notifier).state = '7';
      expect(c.read(visible), 900);
      expect(port.pending, hasLength(1));
      sub.close();
      await Future<void>.delayed(Duration.zero);
      final again = c.listen(visible, (_, __) {});
      addTearDown(again.close);
      expect(c.read(visible), isNull);
      expect(port.pending, hasLength(2));
      port.pending.last.complete(rows(700));
      await c.read(cloneCatalogProvider.future);
      expect(c.read(visible), 900);
    },
  );
}
