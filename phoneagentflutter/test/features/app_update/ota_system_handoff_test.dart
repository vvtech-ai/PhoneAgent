import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/app_update/domain/app_update.dart';
import 'package:phone_agent/features/app_update/domain/update_install.dart';
import 'package:phone_agent/features/app_update/presentation/controller/update_install_controller.dart';
import 'update_install_controller_test.dart'
    show Port, app, release, downloaded;

void main() {
  for (final restored in [false, true]) {
    test(
      'download reaches system without APK inspection, restored=$restored',
      () async {
        final port = Port();
        if (restored) port.restored = downloaded;
        final controller = UpdateInstallController(
          app: app,
          release: release,
          port: port,
          isCurrent: () => true,
        );
        addTearDown(controller.dispose);
        if (restored) {
          await controller.restore();
          expect(controller.state.phase, UpdateInstallPhase.ready);
          expect(port.calls, ['restore']);
        }
        await controller.primary();
        expect(port.calls, isNot(contains('inspect')));
        expect(port.calls, contains('install'));
        expect(port.calls, isNot(contains('cancel')));
        expect(controller.state.phase, UpdateInstallPhase.installing);
      },
    );
  }
  test(
    'backend version, size and checksum metadata do not veto handoff',
    () async {
      final port = Port();
      final metadata = AppUpdateRelease(
        hasUpdate: true,
        packageName: app.packageName,
        versionName: 'different metadata',
        versionCode: 999,
        fileSize: 1,
        checksumSha256: 'b' * 64,
      );
      final controller = UpdateInstallController(
        app: app,
        release: metadata,
        port: port,
        isCurrent: () => true,
      );
      addTearDown(controller.dispose);
      await controller.primary();
      expect(port.calls, ['begin', 'canInstall', 'install']);
      expect(controller.state.error, isEmpty);
    },
  );
  test('missing restored download can be downloaded again', () async {
    final port = Port()
      ..restored = downloaded
      ..handoff = () async => throw const UpdateDownloadUnavailable();
    final controller = UpdateInstallController(
      app: app,
      release: release,
      port: port,
      isCurrent: () => true,
    );
    addTearDown(controller.dispose);
    await controller.restore();
    await controller.primary();
    expect(controller.state.phase, UpdateInstallPhase.failed);
    expect(controller.state.error, contains('重新下载'));
    port.handoff = null;
    await controller.primary();
    expect(port.calls, [
      'restore',
      'canInstall',
      'install',
      'cancel',
      'begin',
      'canInstall',
      'install',
    ]);
    expect(controller.state.phase, UpdateInstallPhase.installing);
  });
}
