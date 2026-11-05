import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/design/native_setting_controls.dart';
import '../../support/developer_tools_fixture.dart';

void main() {
  testWidgets(
    'formal sections follow native and omit legacy and MOCK controls',
    (tester) async {
      await openDeveloperTools(tester);
      final titles = ['列表数据', '外呼调试', '实时翻译', 'V8.8 模拟能力'];
      for (var i = 0; i < titles.length; i++) {
        expect(find.text(titles[i]), findsOneWidget);
        if (i > 0) {
          expect(
            tester.getTopLeft(find.text(titles[i])).dy,
            greaterThan(tester.getTopLeft(find.text(titles[i - 1])).dy),
          );
        }
      }
      for (final text in ['国内强制 WebRTC', '国外服务器', '国外通话模型', '当前定位']) {
        expect(find.text(text), findsNothing);
      }
      expect(find.textContaining('MOCK'), findsNothing);
      expect(find.text('账号翻译模型（调试）'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('$platform 320px at 2x text keeps country/network reachable', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = platform;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final f = await openDeveloperTools(tester);
      tester.view.physicalSize = const Size(320, 640);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpAndSettle();
      final toggle = find.byKey(const Key('developer-country-simulation'));
      await tester.scrollUntilVisible(toggle, 150);
      await tester.ensureVisible(toggle);
      await tester.pumpAndSettle();
      await tester.tap(find.text('模拟国家定位'));
      await tester.pumpAndSettle();
      expect(f.store.value.simulatedCountryIso, 'CN');
      await tester.ensureVisible(find.text('选择 ›'));
      await tester.tap(find.text('选择 ›'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('developer-country-search')),
        'sg',
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('developer-country-SG')));
      await tester.tap(find.byKey(const Key('developer-country-SG')));
      await tester.pumpAndSettle();
      expect(f.store.value.simulatedCountryIso, 'SG');
      final offline = find.byKey(const Key('developer-network-offline'));
      await tester.scrollUntilVisible(offline, 150);
      await tester.ensureVisible(offline);
      await tester.pumpAndSettle();
      await tester.tap(offline);
      await tester.pumpAndSettle();
      expect(tester.widget<NativeSettingChoice>(offline).selected, isTrue);
      expect(tester.takeException(), isNull);
      debugDefaultTargetPlatformOverride = null;
    });
  }
}
