import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_agent/app/app_update_providers.dart';
import 'package:phone_agent/app/business_providers.dart';
import 'package:phone_agent/app/update_install_providers.dart';
import 'package:phone_agent/features/app_update/data/preview_update_install_port.dart';
import 'package:phone_agent/features/app_update/presentation/controller/update_install_controller.dart';
import 'package:phone_agent/features/app_update/data/preview_startup_update.dart';
import 'package:phone_agent/features/app_update/presentation/controller/startup_update_controller.dart';

/// Exercise the normal startup controller with a synthetic same-day record.
/// Dedicated OTA scenes cover offers; this host never reads the device journal.
List<Override> shellStartupOverrides() => [
  installedAppSourceProvider.overrideWithValue(PreviewStartupSource()),
  appUpdateRepositoryProvider.overrideWith((ref) {
    ref.watch(loginEpochProvider);
    return PreviewStartupUpdate(StartupUpdateScenario.optional);
  }),
  updateInstallProvider.overrideWith((ref, launch) {
    ref.watch(loginEpochProvider);
    var active = true;
    ref.onDispose(() => active = false);
    return UpdateInstallController(
      app: launch.app,
      release: launch.release,
      port: PreviewUpdateInstallPort(UpdateInstallScenario.normal),
      isCurrent: () => active,
    );
  }),
  startupUpdateControllerProvider.overrideWith((ref) {
    ref.watch(loginEpochProvider);
    final preview = PreviewStartupUpdate(StartupUpdateScenario.sameDay);
    var active = true;
    ref.onDispose(() => active = false);
    return StartupUpdateController(
      source: preview.source,
      repository: preview,
      store: preview.store,
      recovery: preview,
      isCurrent: () => active,
    );
  }),
];
