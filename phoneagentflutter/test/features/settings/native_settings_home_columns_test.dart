import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/settings/presentation/pages/settings_page.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'native settings fitting summaries stay beside content $platform $scale',
        (tester) async {
          tester.view.physicalSize = Size(scale == 1 ? 320 : 411, 915);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final opened = <SettingsDestination>[];
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(platform: platform),
              home: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                child: Scaffold(
                  body: SettingsPage(
                    onOpen: opened.add,
                    developer: false,
                    identitySummary: '未填写',
                    modelSummary: '模型A',
                    originalSummary: '设置',
                  ),
                ),
              ),
            ),
          );
          expect(find.text('Skill 卡片'), findsOneWidget);
          expect(find.text('管理在任务中使用的背景与偏好'), findsOneWidget);
          expect(find.text('调整首页Skill 卡片的顺序与显示'), findsOneWidget);
          expect(
            tester.getTopLeft(find.text('记忆')).dy,
            lessThan(tester.getTopLeft(find.text('Skill 卡片')).dy),
          );
          await tester.ensureVisible(find.byKey(const Key('settings-models')));
          expect(
            tester.getTopLeft(find.text('Skill 卡片')).dy,
            lessThan(tester.getTopLeft(find.text('语音模型与音色')).dy),
          );
          final value = find.text('模型A ›');
          final description = find.text('通话AI语音、任务AI语音');
          expect(
            tester.getTopLeft(value).dx,
            greaterThan(tester.getTopLeft(description).dx),
          );
          expect(
            tester.getTopLeft(value).dy,
            lessThan(tester.getBottomLeft(description).dy),
          );
          await tester.tap(find.byKey(const Key('settings-models')));
          expect(opened, [SettingsDestination.models]);
          expect(find.byKey(const Key('settings-update')), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
