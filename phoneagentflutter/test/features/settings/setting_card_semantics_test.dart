import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/design/native_setting_controls.dart';
import 'package:phone_agent/features/settings/presentation/pages/settings_page.dart';

void main() {
  testWidgets('action busy and read-only card roles are distinct', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      for (final kind in ['active', 'busy', 'read-only']) {
        var calls = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: NativeSettingCard(
                title: '标题',
                subtitle: '说明',
                value: '当前值 ›',
                isAction: kind == 'busy',
                onTap: kind == 'active' ? () => calls++ : null,
              ),
            ),
          ),
        );
        final finder = find.bySemanticsLabel('标题，说明，当前值');
        final node = tester.getSemantics(finder);
        expect(node.hasFlag(SemanticsFlag.isButton), kind != 'read-only');
        expect(
          node.getSemanticsData().hasAction(SemanticsAction.tap),
          kind == 'active',
        );
        if (kind == 'busy') {
          expect(node.hasFlag(SemanticsFlag.isEnabled), isFalse);
        }
        await tester.tap(finder);
        expect(calls, kind == 'active' ? 1 : 0);
      }
    } finally {
      await tester.pumpWidget(const SizedBox());
      semantics.dispose();
    }
  });
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final large in [false, true]) {
      testWidgets(
        '$platform setting entries remain named while busy large=$large',
        (tester) async {
          tester.view.physicalSize = const Size(320, 568);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final semantics = tester.ensureSemantics();
          final calls = <SettingsDestination>[];
          try {
            await tester.pumpWidget(
              MaterialApp(
                home: MediaQuery(
                  data: MediaQueryData(
                    size: const Size(320, 568),
                    textScaler: TextScaler.linear(large ? 2 : 1),
                  ),
                  child: Scaffold(
                    body: SettingsPage(
                      onOpen: calls.add,
                      developer: true,
                      modelSummary: '合成模型',
                      originalSummary: '关闭',
                      identitySummary: '已填写',
                    ),
                  ),
                ),
              ),
            );
            for (final destination in const [
              SettingsDestination.models,
              SettingsDestination.homeCards,
              SettingsDestination.memory,
              SettingsDestination.originalAudio,
              SettingsDestination.about,
              SettingsDestination.developer,
              SettingsDestination.logout,
            ]) {
              final key = find.byKey(Key('settings-${destination.name}'));
              if (key.evaluate().isEmpty) {
                await tester.scrollUntilVisible(
                  key,
                  160,
                  scrollable: find.byType(Scrollable).last,
                );
              }
              await Scrollable.ensureVisible(
                tester.element(key),
                alignment: .35,
              );
              await tester.pumpAndSettle();
              final card = destination == SettingsDestination.logout
                  ? null
                  : tester.widget<NativeSettingCard>(key);
              final label = card == null
                  ? '退出登录'
                  : [
                      card.title,
                      card.subtitle,
                      card.value.replaceAll('›', '').trim(),
                    ].where((value) => value.isNotEmpty).join('，');
              final node = tester.getSemantics(find.bySemanticsLabel(label));
              expect(node.hasFlag(SemanticsFlag.isButton), isTrue);
              expect(node.hasFlag(SemanticsFlag.isEnabled), true);
              expect(
                node.getSemanticsData().hasAction(SemanticsAction.tap),
                true,
              );
              expect(tester.getSize(key).height, greaterThanOrEqualTo(48));
              final before = calls.length;
              await tester.tap(key);
              await tester.pumpAndSettle();
              expect(calls.length, before + 1);
              expect(tester.takeException(), isNull);
            }
          } finally {
            await tester.pumpWidget(const SizedBox());
            semantics.dispose();
          }
        },
        variant: TargetPlatformVariant({platform}),
      );
    }
  }
}
