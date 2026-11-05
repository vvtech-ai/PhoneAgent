import 'package:phone_agent/features/auth/presentation/widgets/auth_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:phone_agent/app/phone_agent_app.dart';
import 'package:phone_agent/features/auth/presentation/controller/auth_providers.dart';
import 'package:phone_agent/features/settings/presentation/pages/account_route.dart';
import '../tool/previews/auth_scenario.dart';
import '../tool/previews/migration_workbench.dart';
import '../tool/previews/workbench_catalog.dart';
import 'support/pump_ui_transitions.dart';
import 'support/local_storage_channel_fake.dart';

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    installLocalStorageChannelFake();
  });
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      'settings account native flow returns to login $platform',
      (tester) async {
        await tester.pumpWidget(
          MigrationWorkbench(
            scenes: [workbenchScenes.singleWhere((scene) => scene.id == 'app')],
          ),
        );
        Future<void> tap(String key) async {
          final finder = find.byKey(ValueKey(key));
          if (finder.evaluate().isEmpty) {
            await tester.scrollUntilVisible(
              finder,
              200,
              scrollable: find.byType(Scrollable).last,
            );
          }
          await tester.ensureVisible(finder);
          await tester.pumpUntilUiSettled();
          expect(finder.hitTestable(), findsOneWidget);
          await tester.tap(finder);
          await tester.pumpUntilUiSettled();
        }

        await tap('scene-app');
        final container = ProviderScope.containerOf(
          tester.element(find.byType(PhoneAgentApp)),
        );
        final store = container.read(sessionStoreProvider) as AuthScenario;
        await tap('tab-3');
        await tester.scrollUntilVisible(
          find.byKey(const Key('settings-logout')),
          200,
          scrollable: find.byType(Scrollable).last,
        );
        expect(find.text(store.saved!.maskedPhone), findsOneWidget);
        expect(find.byKey(const Key('settings-account')), findsNothing);
        await tap('settings-about');
        await tap('about-account');
        expect(find.byType(AccountRoute), findsOneWidget);
        expect(find.text('账号管理'), findsOneWidget);
        await tap('account-delete');
        await tester.tap(find.text('取消'));
        await tester.pumpUntilUiSettled();
        expect(store.saved, isNotNull);
        await tester.tap(find.byTooltip('返回'));
        await tester.pumpUntilUiSettled();
        expect(find.text('关于PhoneAgent'), findsOneWidget);
        await tap('about-account');
        // Dispatch to the production router, not the workbench's outer navigator.
        expect(
          await container.read(appRouterProvider).routerDelegate.popRoute(),
          isTrue,
        );
        await tester.pumpUntilUiSettled();
        expect(find.text('关于PhoneAgent'), findsOneWidget);
        await tap('about-account');
        await tap('account-delete');
        await tester.enterText(
          find.byKey(const Key('account-confirmation-input')),
          '确认注销',
        );
        await tester.pump();
        await tap('account-entry-confirmation-submit');
        expect(store.saved, isNotNull);
        await tester.enterText(
          find.byKey(const Key('verification-code-input')),
          '123456',
        );
        await tester.pump();
        await tester.pumpUntilUiSettled();
        expect(store.saved, isNotNull);
        await tap('account-confirmation-submit');
        expect(store.saved, isNull);
        expect(find.text('已提交注销申请'), findsOneWidget);
        final surface = find.byKey(const ValueKey('nativeNoticeSurface'));
        expect(
          tester.getCenter(surface).dy,
          closeTo(tester.getCenter(find.byType(AuthFrame)).dy, 20),
        );
        await tester.pump(const Duration(seconds: 3));
        await tester.pumpUntilUiSettled();
        expect(find.text('已提交注销申请'), findsNothing);
        expect(find.byKey(const ValueKey('loginPhone')), findsOneWidget);
        expect(find.byType(AccountRoute), findsNothing);
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant({platform}),
    );
  }
}
