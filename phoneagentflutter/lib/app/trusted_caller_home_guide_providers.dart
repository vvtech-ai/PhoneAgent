import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/config/app_config.dart';
import '../features/trusted_caller/data/device_trusted_caller_home_guide_store.dart';
import '../features/trusted_caller/domain/trusted_caller.dart';
import '../features/trusted_caller/domain/trusted_caller_home_guide.dart';
import '../features/trusted_caller/presentation/controller/trusted_caller_home_guide_controller.dart';
import 'app_providers.dart';
import 'trusted_caller_account_providers.dart';
import 'trusted_caller_providers.dart';

final trustedCallerHomeGuideStoreProvider =
    Provider<TrustedCallerHomeGuideStore>(
      (ref) => DeviceTrustedCallerHomeGuideStore(
        ref.watch(appConfigProvider).environment == AppEnvironment.prod
            ? 'pro'
            : 'test',
      ),
    );

final trustedCallerHomeGuideProvider =
    StateNotifierProvider.autoDispose<
      TrustedCallerHomeGuideController,
      TrustedCallerHomeGuideState
    >((ref) {
      final config = ref.watch(appConfigProvider);
      final owner = ref.watch(trustedCallerOwnerProvider);
      final controller = TrustedCallerHomeGuideController(
        owner: owner ?? const TrustedCallerOwner('', '', -1),
        store: ref.watch(trustedCallerHomeGuideStoreProvider),
        ensureAccount: (captured) =>
            owner?.valid == true &&
                config.isConfigured &&
                config.environment != AppEnvironment.local
            ? ref.read(trustedCallerAccountReadyProvider)(captured)
            : Future.value(false),
      );
      unawaited(controller.load());
      return controller;
    });
