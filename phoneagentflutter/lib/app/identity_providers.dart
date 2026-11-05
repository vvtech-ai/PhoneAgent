import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/identity/data/api_identity_repository.dart';
import '../features/identity/data/identity_initialization_store.dart';
import '../features/identity/domain/identity_profile.dart';
import '../features/identity/domain/identity_deletion_cleanup.dart';
import '../features/identity/presentation/controller/identity_controller.dart';
import 'business_providers.dart';
import 'clone_readiness_provider.dart';
import 'conversation_providers.dart';
import 'app_providers.dart';
import 'certified_recording_providers.dart';
import 'legacy_preferences_providers.dart';

// Deliberately retained across route disposal and sign-out, like v65 prefs.
final identityInitializationStoreProvider = Provider(
  (ref) => IdentityInitializationStore(
    ref.watch(appConfigProvider),
    legacyRead: ref
        .watch(legacyPreferencesSourceProvider)
        ?.readInitializationSkipped,
  ),
);

final identityDeletedEffectProvider = Provider<IdentityDeletionCleanup Function()>((
  ref,
) {
  return () {
    // Recreating the controller discards cached voices and cancels old results.
    // No speculative default model/voice is written to the backend.
    ref.invalidate(callModelControllerProvider);
    ref.invalidate(cloneCatalogProvider);
    return IdentityDeletionCleanup(
      markSkipped: ref.read(identityInitializationStoreProvider).markSkipped,
      clearRecording: ref.read(prepareCertifiedRecordingClearProvider)(),
    );
  };
});

final identityRepositoryProvider = Provider.autoDispose<IdentityRepository>(
  (ref) => ApiIdentityRepository(
    ref.watch(accountApiProvider),
    ref.watch(currentAccountIdProvider),
  ),
);
final identityControllerProvider =
    StateNotifierProvider.autoDispose<IdentityController, IdentityState>((ref) {
      final controller = IdentityController(
        ref.watch(identityRepositoryProvider),
        createDeletionCleanup: ref.watch(identityDeletedEffectProvider),
      );
      controller.load();
      return controller;
    });
