import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/widgets.dart';
import 'dart:async';
import '../features/auth/presentation/controller/auth_providers.dart';
import '../features/conversation/data/artifacts/api_task_artifact_repository.dart';
import '../features/conversation/data/artifacts/device_task_file_destination.dart';
import '../features/conversation/domain/artifacts/task_artifact_download.dart';
import '../features/conversation/presentation/controller/task_artifact_download_controller.dart';
import 'business_providers.dart';

final taskArtifactRepositoryProvider = Provider<TaskArtifactRepository>(
  (ref) => ApiTaskArtifactRepository(ref.watch(accountApiProvider)),
);
final taskFileDestinationProvider = Provider<TaskFileDestination>(
  (ref) => const DeviceTaskFileDestination(),
);

/// Each route owner cancels its own save picker when leaving or switching account.
final taskArtifactDownloadProvider = ChangeNotifierProvider.autoDispose
    .family<TaskArtifactDownloadController, Object>((ref, routeOwner) {
      ref.watch(loginEpochProvider);
      final session = ref.watch(sessionControllerProvider.notifier),
          owner = session.credentials;
      var alive = true;
      ref.onDispose(() {
        alive = false;
      });
      final controller = TaskArtifactDownloadController(
        repository: ref.watch(taskArtifactRepositoryProvider),
        destination: ref.watch(taskFileDestinationProvider),
        isCurrent: () =>
            alive && owner != null && owner.sameLogin(session.credentials),
      );
      final lifecycle = AppLifecycleListener(
        onResume: () => unawaited(controller.refreshSaved()),
      );
      ref.onDispose(lifecycle.dispose);
      return controller;
    });
