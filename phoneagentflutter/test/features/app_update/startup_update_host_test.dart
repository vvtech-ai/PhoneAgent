import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/app_update_providers.dart';
import 'package:phone_agent/app/business_providers.dart';
import 'package:phone_agent/app/update_install_providers.dart';
import 'package:phone_agent/features/app_update/data/preview_update_install_port.dart';
import 'package:phone_agent/features/app_update/presentation/controller/startup_update_controller.dart';
import 'package:phone_agent/features/app_update/presentation/controller/update_install_controller.dart';
import 'package:phone_agent/features/app_update/presentation/widgets/startup_update_host.dart';
import '../../support/startup_update_fakes.dart';

void main() {
  late StartupRepositoryFake repo;
  late StartupRecoveryFake recovery;
  late StartupUpdateController controller;
  int created = 0;
  setUp(() {
    repo = StartupRepositoryFake();
    recovery = StartupRecoveryFake();
    created = 0;
    controller = StartupUpdateController(
      source: StartupSourceFake(),
      repository: repo,
      store: StartupStoreFake(),
      recovery: recovery,
      isCurrent: () => true,
    );
  });
  Future<void> open(WidgetTester tester, {bool supported = true}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          startupUpdateSupportedProvider.overrideWithValue(supported),
          loginEpochProvider.overrideWithValue(1),
          startupUpdateControllerProvider.overrideWith((ref) {
            created++;
            return controller;
          }),
          updateInstallProvider.overrideWith(
            (ref, launch) => UpdateInstallController(
              app: launch.app,
              release: launch.release,
              port: PreviewUpdateInstallPort(UpdateInstallScenario.normal),
              isCurrent: () => true,
            ),
          ),
        ],
        child: const MaterialApp(
          home: StartupUpdateHost(child: Scaffold(body: Text('合成首页'))),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('unsupported platform never creates controller or queries', (
    tester,
  ) async {
    await open(tester, supported: false);
    expect(created, 0);
    expect(repo.checks, 0);
    controller.dispose();
  });
  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets(
      'optional dialog at $width rejects outside dismissal but allows Later',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 640);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await open(tester);
        expect(find.text('发现新版本'), findsOneWidget);
        await tester.tapAt(const Offset(2, 2));
        await tester.pumpAndSettle();
        expect(find.text('发现新版本'), findsOneWidget);
        await tester.tap(find.byKey(const Key('startup-update-later')));
        await tester.pumpAndSettle();
        expect(find.text('发现新版本'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'force blocks back and has no Later; authoritative no-update removes modal',
    (tester) async {
      repo.release = startupRelease(force: true);
      await open(tester);
      expect(find.text('稍后'), findsNothing);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('发现重要版本更新'), findsOneWidget);
      await controller.acceptManual(startupApp, startupRelease(update: false));
      await tester.pumpAndSettle();
      expect(find.text('发现重要版本更新'), findsNothing);
      expect(find.text('合成首页'), findsOneWidget);
    },
  );
  testWidgets('offer to installation then Later closes both owned routes', (
    tester,
  ) async {
    await open(tester);
    final offerRoute = ModalRoute.of(tester.element(find.byType(Dialog)));
    await tester.tap(find.byKey(const Key('startup-update-install')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('update-install-status')), findsOneWidget);
    expect(find.byType(Dialog), findsOneWidget);
    expect(
      ModalRoute.of(tester.element(find.byType(Dialog))),
      same(offerRoute),
    );
    await tester.tap(find.byKey(const Key('update-install-close')));
    await tester.pumpAndSettle();
    expect(find.text('合成首页'), findsOneWidget);
    expect(find.text('发现新版本'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('recovered download opens install recovery without version API', (
    tester,
  ) async {
    recovery.release = startupRelease();
    await open(tester);
    expect(repo.checks, 0);
    expect(find.byKey(const Key('update-install-status')), findsOneWidget);
    expect(find.byType(Dialog), findsOneWidget);
    await tester.tap(find.byKey(const Key('update-install-close')));
    await tester.pumpAndSettle();
    expect(find.text('合成首页'), findsOneWidget);
  });
  testWidgets(
    'host disposal closes owned force route without popping unrelated route',
    (tester) async {
      repo.release = startupRelease(force: true);
      await open(tester);
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Text('新会话'))),
      );
      await tester.pumpAndSettle();
      expect(find.text('新会话'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
