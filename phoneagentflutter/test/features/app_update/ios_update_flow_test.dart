import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/app_update_providers.dart';
import 'package:phone_agent/app/update_install_providers.dart';
import 'package:phone_agent/features/app_update/data/ios_update_link_port.dart';
import 'package:phone_agent/features/app_update/domain/app_update.dart';
import 'package:phone_agent/features/app_update/presentation/controller/startup_update_controller.dart';
import 'package:phone_agent/features/app_update/presentation/widgets/startup_update_host.dart';
import '../../support/startup_update_fakes.dart';

void main() {
  test(
    'no active login never reads metadata, recovery or version API',
    () async {
      final source = StartupSourceFake(), repo = StartupRepositoryFake();
      final recovery = StartupRecoveryFake();
      final controller = StartupUpdateController(
        source: source,
        repository: repo,
        store: StartupStoreFake(),
        recovery: recovery,
        isCurrent: () => false,
      );
      await controller.start();
      expect(source.reads, 0);
      expect(recovery.reads, 0);
      expect(repo.checks, 0);
      controller.dispose();
    },
  );
  testWidgets(
    'iOS host opens external link, retains force on recheck failure and clears on authoritative result',
    (tester) async {
      final repo = StartupRepositoryFake()
        ..release = const AppUpdateRelease(
          hasUpdate: true,
          packageName: 'com.example.synthetic',
          versionName: '2.0',
          forceUpdate: true,
          sourceType: 1,
          iosSourceUrl: 'https://apps.apple.com/app/id6813455647',
        );
      final controller = StartupUpdateController(
        source: StartupSourceFake(),
        repository: repo,
        store: StartupStoreFake(),
        recovery: StartupRecoveryFake(),
        isCurrent: () => true,
      );
      final links = _Links();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            startupUpdateControllerProvider.overrideWith((ref) => controller),
            iosUpdateLinkPortProvider.overrideWithValue(links),
            updateInstallProvider.overrideWith(
              (ref, launch) =>
                  throw StateError('Android install must not be created'),
            ),
          ],
          child: const MaterialApp(
            home: StartupUpdateHost(child: Scaffold(body: Text('首页'))),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(repo.checks, 1);
      expect(find.text('发现重要版本更新'), findsOneWidget);
      await tester.tap(find.byKey(const Key('startup-update-install')));
      await tester.pumpAndSettle();
      expect(links.opens, 1);
      expect(find.byKey(const Key('update-install-status')), findsNothing);
      repo.fail = true;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(repo.checks, 2);
      expect(find.text('发现重要版本更新'), findsOneWidget);
      expect(find.text('版本检查失败，请稍后重试'), findsOneWidget);
      await controller.acceptManual(startupApp, startupRelease(update: false));
      await tester.pumpAndSettle();
      expect(find.text('发现重要版本更新'), findsNothing);
      expect(find.text('首页'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
    variant: TargetPlatformVariant({TargetPlatform.iOS}),
  );
}

class _Links extends IosUpdateLinkPort {
  int opens = 0;
  @override
  Future<void> open(String link) async {
    opens++;
  }
}
