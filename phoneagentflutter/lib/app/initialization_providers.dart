import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/initialization/data/repository_initialization_gateway.dart';
import '../features/initialization/presentation/controller/initialization_controller.dart';
import 'business_providers.dart';
import 'identity_providers.dart';
import '../features/initialization/presentation/controller/initialization_model_switch_controller.dart';

final initializationModelSwitchProvider =
    StateNotifierProvider<InitializationModelSwitchController, String>((ref) {
      ref.watch(loginEpochProvider);
      final calls = ref.watch(callModelRepositoryProvider);
      return InitializationModelSwitchController((id) async {
        await calls.select(id);
      }, () => ref.invalidate(callModelControllerProvider));
    });

final initializationControllerProvider =
    StateNotifierProvider.autoDispose<
      InitializationController,
      InitializationState
    >((ref) {
      ref.watch(loginEpochProvider);
      var current = true;
      ref.onDispose(() => current = false);
      final controller = InitializationController(
        RepositoryInitializationGateway(
          identity: ref.watch(identityRepositoryProvider),
          calls: ref.watch(callModelRepositoryProvider),
          skipStore: ref.watch(identityInitializationStoreProvider),
        ),
        onModelSwitch: (id, name) {
          ref.read(initializationModelSwitchProvider.notifier).select(id, name);
        },
      );
      final remove = controller.addListener((state) {
        if (current && state.ready && state.finished) {
          ref.invalidate(identityControllerProvider);
          ref.invalidate(callModelControllerProvider);
        }
      }, fireImmediately: false);
      ref.onDispose(remove);
      controller.load();
      return controller;
    });
