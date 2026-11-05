import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/settings/presentation/pages/settings_page.dart';
import 'package:phone_agent/features/settings/presentation/widgets/logout_dialog.dart';

void main() {
  testWidgets('native settings state sits right of description', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SettingsPage(
            developer: false,
            modelSummary: 'Seeduplex',
            originalSummary: '关闭',
            identitySummary: '已填写',
            onOpen: (_) {},
          ),
        ),
      ),
    );
    expect(find.text('我的身份'), findsNothing);
    expect(
      tester.getCenter(find.text('Seeduplex ›')).dx,
      greaterThan(tester.getCenter(find.text('语音模型与音色')).dx),
    );
  });

  testWidgets(
    'small screen large type preserves every settings action',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final opened = <SettingsDestination>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SettingsPage(
              developer: true,
              modelSummary: '很长的模型名称和倍率用于验证状态完整可读',
              originalSummary: '尚未保存',
              identitySummary: '已认证',
              onOpen: opened.add,
            ),
          ),
        ),
      );
      for (final id in [
        SettingsDestination.memory,
        SettingsDestination.homeCards,
        SettingsDestination.models,
        SettingsDestination.originalAudio,
        SettingsDestination.trustedCaller,
        SettingsDestination.feedback,
        SettingsDestination.about,
        SettingsDestination.developer,
        SettingsDestination.logout,
      ]) {
        final entry = find.byKey(Key('settings-${id.name}'));
        await tester.scrollUntilVisible(entry, 150);
        await tester.ensureVisible(entry);
        await tester.pumpAndSettle();
        await tester.tap(entry);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      expect(
        opened,
        unorderedEquals(
          SettingsDestination.values.where(
            (id) =>
                id != SettingsDestination.identity &&
                id != SettingsDestination.invite,
          ),
        ),
      );
    },
    variant: TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.iOS,
    }),
  );

  testWidgets(
    'native logout remains readable and cancel never signs out at large type',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showLogoutConfirmation(context, () async {
                  calls++;
                }),
                child: const Text('打开'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();
      expect(find.text('退出登录？'), findsOneWidget);
      await tester.ensureVisible(find.text('取消'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(calls, 0);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.iOS,
    }),
  );
}
