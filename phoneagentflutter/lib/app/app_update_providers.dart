import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../features/app_update/data/api_app_update_repository.dart';
import '../features/app_update/data/shared_app_update_repository.dart';
import '../features/app_update/data/installed_app_channel.dart';
import '../features/app_update/domain/app_update.dart';
import '../features/app_update/presentation/controller/app_update_controller.dart';
import '../features/auth/presentation/controller/auth_providers.dart';
import 'app_providers.dart';
import 'business_providers.dart';
import '../features/app_update/domain/startup_update.dart';
import '../features/app_update/data/device_update_install_port.dart';
import '../features/app_update/data/secure_startup_update_store.dart';
import '../features/app_update/presentation/controller/startup_update_controller.dart';
import 'update_scope.dart';
import '../features/app_update/data/ios_update_link_port.dart';

final iosUpdateLinkPortProvider = Provider((_) => const IosUpdateLinkPort());

bool get _mobileUpdateSupported =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

final startupUpdateSupportedProvider = Provider<bool>(
  (ref) => _mobileUpdateSupported,
);

final startupUpdateControllerProvider =
    StateNotifierProvider.autoDispose<
      StartupUpdateController,
      StartupUpdateState
    >((ref) {
      ref.watch(loginEpochProvider);
      final config = ref.watch(appConfigProvider);
      final session = ref.read(sessionControllerProvider.notifier);
      final owner = session.credentials;
      var closed = false;
      ref.onDispose(() => closed = true);
      return StartupUpdateController(
        source: ref.watch(installedAppSourceProvider),
        repository: ref.watch(appUpdateRepositoryProvider),
        store: SecureStartupUpdateStore(
          jsonEncode([config.environment?.name, config.apiBaseUri?.toString()]),
        ),
        recovery: _Recovery(
          (app) => defaultTargetPlatform == TargetPlatform.iOS
              ? Future.value(null)
              : DeviceUpdateInstallPort(
                  scope: updateInstallScope(
                    config,
                    owner?.accountId,
                    app.packageName,
                  ),
                ).peek(app),
        ),
        isCurrent: () =>
            !closed && owner != null && owner.sameLogin(session.credentials),
      );
    });

class _Recovery implements StartupUpdateRecovery {
  _Recovery(this.load);
  final Future<AppUpdateRelease?> Function(InstalledApp) load;
  @override
  Future<AppUpdateRelease?> peek(InstalledApp app) => load(app);
}

final installedAppSourceProvider = Provider<InstalledAppSource>(
  (_) => InstalledAppChannel(supported: _mobileUpdateSupported),
);
final appUpdateRepositoryProvider = Provider.autoDispose<AppUpdateRepository>((
  ref,
) {
  ref.watch(loginEpochProvider);
  return SharedAppUpdateRepository(
    ApiAppUpdateRepository(
      ref.watch(accountApiProvider),
      accountId:
          ref.read(sessionControllerProvider.notifier).credentials?.accountId ??
          '',
      channel: ref.watch(appConfigProvider).environment?.name ?? '',
      sourceType: defaultTargetPlatform == TargetPlatform.iOS ? 1 : 0,
    ),
  );
});
final appUpdateControllerProvider =
    StateNotifierProvider.autoDispose<AppUpdateController, AppUpdateState>((
      ref,
    ) {
      return AppUpdateController(
        ref.watch(installedAppSourceProvider),
        ref.watch(appUpdateRepositoryProvider),
        onChecked: ref.watch(startupUpdateSupportedProvider)
            ? ref.read(startupUpdateControllerProvider.notifier).acceptManual
            : null,
      );
    });
