import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/business_providers.dart';
import 'package:phone_agent/app/identity_providers.dart';
import 'package:phone_agent/app/initialization_providers.dart';
import 'package:phone_agent/features/call_models/domain/call_models.dart';
import 'package:phone_agent/features/identity/data/preview_identity_cleanup.dart';
import 'package:phone_agent/features/identity/domain/identity_profile.dart';
import '../../../tool/previews/shell_initialization_store.dart';
import '../../support/shell_fakes.dart';

class _Identity extends PreviewIdentityCleanup {
  _Identity() {
    value = const IdentityProfile(accountId: 'synthetic');
  }
  bool failLoad = false, failSave = false;
  int saves = 0;
  @override
  Future<IdentityProfile> load() async {
    if (failLoad) throw StateError('synthetic load');
    return value;
  }

  @override
  Future<IdentityProfile> save(
    IdentityDraft draft, {
    required bool verified,
  }) async {
    saves++;
    if (failSave) throw StateError('synthetic save');
    return super.save(draft, verified: verified);
  }
}

class _Models extends FakeCallModelRepository {
  Completer<CallModelCatalog>? gate;
  @override
  Future<CallModelCatalog> select(String provider) =>
      gate?.future ?? super.select(provider);
}

void main() {
  final epoch = StateProvider((ref) => 1);
  ProviderContainer mount(_Identity identity, _Models models) {
    final container = ProviderContainer(
      overrides: [
        loginEpochProvider.overrideWith((ref) => ref.watch(epoch)),
        identityRepositoryProvider.overrideWithValue(identity),
        callModelRepositoryProvider.overrideWithValue(models),
        identityInitializationStoreProvider.overrideWithValue(
          ShellInitializationStore(identity),
        ),
      ],
    );
    container.listen(initializationControllerProvider, (_, _) {});
    addTearDown(container.dispose);
    return container;
  }

  test(
    'formal provider retries load and final identity without reselecting model',
    () async {
      final identity = _Identity()..failLoad = true;
      final models = _Models();
      final container = mount(identity, models);
      await Future<void>.delayed(Duration.zero);
      final controller = container.read(
        initializationControllerProvider.notifier,
      );
      expect(controller.snapshot.finished, isFalse);
      expect(controller.snapshot.error, isNotEmpty);
      expect(models.saves, 0);
      identity.failLoad = false;
      identity.failSave = true;
      await controller.load();
      controller.edit(name: '合成资料');
      await controller.next();
      controller.select('DOUBAO');
      await controller.next();
      expect(controller.snapshot.error, contains('身份资料保存失败'));
      expect(models.saves, 1);
      expect(controller.snapshot.finished, isFalse);
      identity.failSave = false;
      await controller.next();
      expect(controller.snapshot.finished, isTrue);
      expect(models.saves, 1);
      expect(identity.saves, 2);
      expect(identity.value.name, '合成资料');
    },
  );

  test(
    'epoch replacement disposes old model feedback after independent skip save',
    () async {
      final identity = _Identity();
      final models = _Models()..gate = Completer<CallModelCatalog>();
      final container = mount(identity, models);
      await Future<void>.delayed(Duration.zero);
      final old = container.read(initializationControllerProvider.notifier);
      old.skipIdentity();
      final pending = old.next();
      expect(old.snapshot.saving, isTrue);
      container.read(epoch.notifier).state = 2;
      await container.pump();
      expect(old.mounted, isFalse);
      models.gate!.complete(models.catalog);
      await pending;
      expect(identity.saves, 0);
      expect(identity.skipWrites, 1);
      expect(container.read(initializationModelSwitchProvider), isEmpty);
      expect(
        container.read(initializationControllerProvider.notifier),
        isNot(same(old)),
      );
    },
  );
}
