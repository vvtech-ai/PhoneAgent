import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/app_update/data/preview_update_install_port.dart';
import 'package:phone_agent/features/app_update/domain/app_update.dart';
import 'package:phone_agent/features/app_update/domain/update_install.dart';
import 'package:phone_agent/features/app_update/presentation/controller/update_install_controller.dart';
import 'package:phone_agent/features/app_update/presentation/pages/update_install_page.dart';

class _Port extends PreviewUpdateInstallPort {
  _Port({bool recovered = false})
    : super(
        recovered
            ? UpdateInstallScenario.restored
            : UpdateInstallScenario.normal,
      );
  int begins = 0, installs = 0, cancels = 0;
  @override
  Future<UpdateDownload> begin(AppUpdateRelease release) {
    begins++;
    return super.begin(release);
  }

  @override
  Future<void> install(String job) async {
    installs++;
  }

  @override
  Future<void> cancel(String job) async {
    cancels++;
  }
}

void main() {
  for (final force in [false, true]) {
    testWidgets('confirmed offer downloads in dialog at 2x (force=$force)', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 640);
      addTearDown(tester.view.reset);
      final port = _Port();
      final controller = UpdateInstallController(
        app: PreviewUpdateInstallPort.app,
        release: AppUpdateRelease(
          hasUpdate: true,
          packageName: PreviewUpdateInstallPort.app.packageName,
          versionName: '1.1.0',
          versionCode: 2,
          fileSize: 1024,
          forceUpdate: force,
          apkUrl: 'https://synthetic.invalid/update.apk',
          releaseNotes: List.filled(30, '体验优化与问题修复').join('。'),
        ),
        port: port,
        isCurrent: () => true,
      );
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: UpdateInstallPage(
            controller: controller,
            dialog: true,
            autoStart: true,
            disposeController: true,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(port.begins, 1);
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.byType(AppBar), findsNothing);
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 600));
      }
      expect(find.text('授权安装'), findsOneWidget);
      expect(port.installs, 0);
      if (force) {
        await tester.binding.handlePopRoute();
        await tester.pump();
        expect(port.cancels, 0);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  }
  testWidgets('recovered dialog cannot install without a fresh action', (
    tester,
  ) async {
    final port = _Port(recovered: true)..allowed = true;
    final controller = UpdateInstallController(
      app: PreviewUpdateInstallPort.app,
      release: PreviewUpdateInstallPort.release,
      port: port,
      isCurrent: () => true,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: UpdateInstallPage(
          controller: controller,
          dialog: true,
          disposeController: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('安装'), findsOneWidget);
    expect(port.begins, 0);
    expect(port.installs, 0);
    await tester.tap(find.byKey(const Key('update-install-primary')));
    await tester.pumpAndSettle();
    expect(port.installs, 1);
  });
}
