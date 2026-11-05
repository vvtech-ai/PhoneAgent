import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/initialization/presentation/pages/initialization_preview_route.dart';

void main() {
  Future<void> open(WidgetTester tester, String name) async {
    await tester.pumpWidget(
      const MaterialApp(home: InitializationScenariosPage()),
    );
    await tester.tap(find.text(name));
    await tester.pumpAndSettle();
  }

  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets('initialization $width draft back models and completion', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, width == 320 ? 568 : 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await open(tester, '填写资料与两步完成');
      expect(find.text('身份信息'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('init-name')), '合成测试');
      await tester.pump();
      await tester.tap(find.text('下一步'));
      await tester.pumpAndSettle();
      expect(find.text('通话语音模型'), findsOneWidget);
      await tester.tap(find.byTooltip('返回上一步'));
      await tester.pumpAndSettle();
      expect(find.text('合成测试'), findsOneWidget);
      await tester.tap(find.text('下一步'));
      await tester.pumpAndSettle();
      expect(find.text('同声传译模型'), findsNothing);
      await tester.tap(find.text('完成'));
      await tester.pumpAndSettle();
      expect(find.text('MOCK · 流程已完成或无需引导，真实账号未改变'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('keyboard viewport scrolls identity fields without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 250);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await open(tester, '填写资料与两步完成');
    await tester.ensureVisible(find.byKey(const ValueKey('init-name')));
    await tester.enterText(find.byKey(const ValueKey('init-name')), '键盘测试');
    await tester.ensureVisible(find.byKey(const ValueKey('init-phone')));
    await tester.enterText(
      find.byKey(const ValueKey('init-phone')),
      '123abc456789012',
    );
    expect(find.text('12345678901'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('skip and local save failure retry without leaving flow', (
    tester,
  ) async {
    await open(tester, '跳过身份与偏好保存失败');
    await tester.tap(find.text('跳过'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();
    expect(find.text('跳过状态尚未保存，请重试'), findsOneWidget);
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();
    expect(find.text('首次初始化演练'), findsOneWidget);
  });
  testWidgets('load retry system back steps then exit returns source', (
    tester,
  ) async {
    await open(tester, '加载失败与重试');
    expect(find.text('初始化资料加载失败，请重试'), findsOneWidget);
    await tester.tap(find.text('重试加载'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('跳过'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('身份信息'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('首次初始化演练'), findsOneWidget);
  });
}
