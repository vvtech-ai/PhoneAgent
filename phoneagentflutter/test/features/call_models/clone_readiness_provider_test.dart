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
  Future<int> availablePoints() => throw StateError('unexpected points read');
  @override
  Future<bool> hasValidRecording() =>
      throw StateError('unexpected recording read');
}

void main() {
  test(
    'completion includes charged ready candidates, failure and refresh remain facts',
    () async {
      final port = _Port();
      final container = ProviderContainer(
        overrides: [
          loginEpochProvider.overrideWithValue(1),
          cloneCreationPortProvider.overrideWithValue(port),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(cloneReadinessProvider, (_, __) {});
      addTearDown(subscription.close);
      expect(container.read(cloneReadinessProvider).isLoading, isTrue);
      port.pending.last.complete([
        const CloneCreationModel(
          pricePoints: 300,
          id: 'QWEN_OMNI_PLUS',
          name: '模型A',
          candidateReady: true,
        ),
      ]);
      expect(await container.read(cloneReadinessProvider.future), isTrue);
      container.invalidate(cloneCatalogProvider);
      final ready = container.read(cloneReadinessProvider.future);
      port.pending.last.complete([
        const CloneCreationModel(
          pricePoints: 300,
          id: 'SEEDUPLEX_3_0',
          name: '模型B',
          currentReady: true,
        ),
      ]);
      expect(await ready, isTrue);
      container.invalidate(cloneCatalogProvider);
      final failed = container.read(cloneReadinessProvider.future);
      port.pending.last.completeError(StateError('synthetic failure'));
      await expectLater(failed, throwsStateError);
      expect(container.read(cloneReadinessProvider).hasError, isTrue);
      // Riverpod retains the previous fact; presentation must prioritize error.
      expect(container.read(cloneReadinessProvider).valueOrNull, isTrue);
    },
  );

  test(
    'login changes discard late old readiness and signout performs no read',
    () async {
      final epoch = StateProvider<int?>((_) => 1);
      final port = _Port();
      final container = ProviderContainer(
        overrides: [
          loginEpochProvider.overrideWith((ref) => ref.watch(epoch)),
          cloneCreationPortProvider.overrideWithValue(port),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(cloneReadinessProvider, (_, __) {});
      addTearDown(subscription.close);
      container.read(cloneReadinessProvider);
      final old = port.pending.single;
      container.read(epoch.notifier).state = 2;
      final current = container.read(cloneReadinessProvider.future);
      old.complete([
        const CloneCreationModel(
          pricePoints: 300,
          id: 'QWEN_OMNI_PLUS',
          name: '旧模型',
          currentReady: true,
        ),
      ]);
      port.pending.last.complete([]);
      expect(await current, isFalse);
      container.read(epoch.notifier).state = null;
      expect(await container.read(cloneReadinessProvider.future), isNull);
      expect(port.pending.length, 2);
    },
  );
}
