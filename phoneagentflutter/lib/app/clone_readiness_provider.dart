import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/call_models/domain/call_models.dart';
import '../features/voice_clone/domain/clone_creation.dart';
import 'business_providers.dart';
import 'clone_flow_providers.dart';

/// Shared account-scoped directory for entry price and current asset readiness.
final cloneCatalogProvider =
    FutureProvider.autoDispose<List<CloneCreationModel>>((ref) async {
      if (ref.watch(loginEpochProvider) == null) return const [];
      return ref.watch(cloneCreationPortProvider).models();
    });

/// Candidate readiness does not imply an available current clone.
final cloneReadinessProvider = FutureProvider.autoDispose<bool?>((ref) async {
  if (ref.watch(loginEpochProvider) == null) return null;
  final models = await ref.watch(cloneCatalogProvider.future);
  return models.any((model) => model.currentReady || model.candidateReady);
});

final cloneEntryPriceProvider = Provider.autoDispose.family<int?, String?>((
  ref,
  modelId,
) {
  if (ref.watch(loginEpochProvider) == null || modelId == null) return null;
  final catalog = ref.watch(cloneCatalogProvider);
  // Never expose previous data during refresh, errors or an account change.
  if (catalog.isLoading || catalog.hasError) return null;
  final matching = (catalog.valueOrNull ?? const <CloneCreationModel>[]).where(
    (m) => normalizeProvider(m.id) == normalizeProvider(modelId),
  );
  if (matching.length != 1 || !matching.single.hasPrice) return null;
  return matching.single.pricePoints;
});
