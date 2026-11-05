import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/app_update/presentation/pages/app_update_preview_page.dart';

void main() {
  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets('shared preview handles all outcomes at width $width', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 640);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MaterialApp(home: AppUpdatePreviewPage()));
      expect(find.text('MOCK · 版本检查演练'), findsOneWidget);
      await tester.tap(find.text('检查更新'));
      await tester.pumpAndSettle();
      expect(find.text('发现新版本'), findsOneWidget);
      for (final entry in {
        '检查失败': '版本检查失败，请稍后重试',
        '无新版本': '当前已是最新版本',
        '重要版本': '发现重要版本更新',
      }.entries) {
        await tester.ensureVisible(find.byType(DropdownButton<String>));
        await tester.tap(find.byType(DropdownButton<String>));
        await tester.pumpAndSettle();
        await tester.tap(find.text(entry.key).last);
        await tester.pumpAndSettle();
        final button = find.byType(FilledButton);
        await tester.ensureVisible(button);
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(find.text(entry.value), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
      final install = find.text('继续下载与安装演练（MOCK）');
      await tester.scrollUntilVisible(install, 180);
      await tester.tap(install);
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('发现重要版本更新'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
