import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/app_update/data/device_update_install_port.dart';
import '../features/app_update/domain/app_update.dart';
import '../features/app_update/presentation/controller/update_install_controller.dart';
import '../features/auth/presentation/controller/auth_providers.dart';
import 'app_providers.dart';
import 'business_providers.dart';
import 'update_scope.dart';

typedef UpdateInstallLaunch = ({InstalledApp app, AppUpdateRelease release});

final updateInstallProvider = StateNotifierProvider.autoDispose
    .family<UpdateInstallController, UpdateInstallState, UpdateInstallLaunch>((
      ref,
      launch,
    ) {
      ref.watch(loginEpochProvider);
      final session = ref.read(sessionControllerProvider.notifier);
      final owner = session.credentials;
      final config = ref.watch(appConfigProvider);
      final scope = updateInstallScope(
        config,
        owner?.accountId,
        launch.app.packageName,
      );
      var closed = false;
      ref.onDispose(() => closed = true);
      return UpdateInstallController(
        app: launch.app,
        release: launch.release,
        port: DeviceUpdateInstallPort(scope: scope),
        isCurrent: () =>
            !closed && owner != null && owner.sameLogin(session.credentials),
      );
    });
