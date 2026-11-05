import '../../identity/domain/identity_profile.dart';
import '../../identity/data/identity_initialization_store.dart';
import '../../call_models/domain/call_models.dart';
import '../domain/initialization_gateway.dart';

/// Account-bound repositories retain their existing authentication protections.
/// Onboarding has no translation or native capability dependency.
class RepositoryInitializationGateway implements InitializationGateway {
  const RepositoryInitializationGateway({
    required this.identity,
    required this.calls,
    required this.skipStore,
  });
  final IdentityRepository identity;
  final CallModelRepository calls;
  final IdentityInitializationStore skipStore;
  @override
  Future<bool> isSkipped() => skipStore.isSkipped();
  @override
  Future<IdentityProfile> loadIdentity() => identity.load();
  @override
  Future<InitializationCatalog> loadCallModels() async {
    final catalog = await calls.load();
    return InitializationCatalog(catalog.activeProvider, [
      for (final model in catalog.models)
        InitializationModel(
          model.id,
          model.name,
          model.description,
          enabled: model.available,
          recommended: model.recommended,
        ),
    ]);
  }

  @override
  Future<void> selectCallModel(String id) async {
    await calls.select(id);
  }

  @override
  Future<void> saveIdentity(IdentityDraft draft) async {
    await identity.save(draft, verified: false);
  }

  @override
  Future<void> markSkipped() => skipStore.markSkipped();
}
