import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/business_providers.dart';
import '../../../../app/clone_readiness_provider.dart';
import '../../../../app/identity_providers.dart';
import '../../../../app/points_providers.dart';
import '../../../voice_clone/presentation/pages/clone_creation_route.dart';

/// Refresh the model actually visited, including a different model picked globally.
Future<void> openShellCloneFlow(
  BuildContext context,
  WidgetRef ref, {
  String? targetModelId,
  required bool Function() isCurrent,
}) async {
  final owner = ref.read(loginEpochProvider);
  bool current() => isCurrent() && owner == ref.read(loginEpochProvider);
  String? completedModel;
  await openCloneCreation(
    context,
    targetModelId: targetModelId,
    onModelStarted: (model) => completedModel = model,
  );
  if (!current() || completedModel == null) return;
  ref.invalidate(identityControllerProvider);
  ref.invalidate(cloneCatalogProvider);
  ref.read(pointsWalletControllerProvider.notifier).refresh();
  final controller = ref.read(callModelControllerProvider.notifier);
  await controller.load();
  if (!current()) return;
  final models = ref.read(callModelControllerProvider).catalog?.models;
  final target = models
      ?.where((m) => m.capabilityProvider == completedModel)
      .firstOrNull;
  await controller.loadVoices(target?.id ?? completedModel!);
}
