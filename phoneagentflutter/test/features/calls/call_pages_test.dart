import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/calls/presentation/controller/call_preview_controller.dart';
import 'package:phone_agent/features/calls/presentation/pages/call_preview_route.dart';

void main() {
  Future<void> open(WidgetTester tester, String scenario) async {
    await tester.pumpWidget(
      const MaterialApp(home: CallPreviewScenariosPage()),
    );
    await tester.tap(find.text(scenario));
    await tester.pumpAndSettle();
  }

  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets(
      'shared call page $width fits and source sheet obeys monitor state',
      (tester) async {
        tester.view.physicalSize = Size(width, width == 320 ? 568 : 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await open(
          tester,
          CallPreviewScenariosPage.labels[CallPreviewScenario.connected]!,
        );
        expect(find.text('你好，这是合成对话。'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.byKey(const ValueKey('call-音源，听筒')));
        await tester.pumpAndSettle();
        expect(find.text('发声源'), findsOneWidget);
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('call-开始监听')));
        await tester.pumpAndSettle();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpAndSettle();
        expect(find.text('正在监听'), findsNothing);
        await tester.tap(find.byKey(const ValueKey('call-音源，听筒')));
        await tester.pumpAndSettle();
        expect(find.text('蓝牙'), findsNothing);
        await tester.tap(find.byKey(const ValueKey('source-speaker')));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('call-音源，扬声器')), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('call-停止监听')));
        await tester.pumpAndSettle();
        expect(find.text('监听已静音'), findsNothing);
        await tester.tap(find.text('退出演练'));
        await tester.pumpAndSettle();
        expect(find.text('单路通话页面演练'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  testWidgets(
    'bluetooth sheet cancel preserves route and system back cleans call',
    (tester) async {
      await open(
        tester,
        CallPreviewScenariosPage.labels[CallPreviewScenario.bluetooth]!,
      );
      await tester.tap(find.byKey(const ValueKey('call-开始监听')));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('call-音源，听筒')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('source-bluetooth')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('call-音源，蓝牙')));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('call-音源，蓝牙')), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('单路通话页面演练'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('hangup failure stays visible then successful retry returns', (
    tester,
  ) async {
    await open(
      tester,
      CallPreviewScenariosPage.labels[CallPreviewScenario.hangupError]!,
    );
    await tester.tap(find.byKey(const ValueKey('call-挂断')));
    await tester.pumpAndSettle();
    expect(find.text('挂断失败，尚未确认电话结束，请重试'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('call-挂断')));
    await tester.pumpAndSettle();
    expect(find.text('单路通话页面演练'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'terminal waits outcome without fake success and controls disabled',
    (tester) async {
      await open(
        tester,
        CallPreviewScenariosPage.labels[CallPreviewScenario.awaitingOutcome]!,
      );
      expect(find.text('通话已结束，等待任务结果'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('call-挂断')));
      await tester.pumpAndSettle();
      expect(find.text('退出演练'), findsOneWidget);
      await tester.tap(find.text('演练控制'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('模拟任务结果到达'));
      await tester.pumpAndSettle();
      expect(find.text('通话已结束'), findsOneWidget);
      expect(find.text('任务成功'), findsNothing);
      await tester.tap(find.text('退出演练'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
    },
  );
}
