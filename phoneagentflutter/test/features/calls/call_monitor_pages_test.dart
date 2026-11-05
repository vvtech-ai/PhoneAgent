import 'package:phone_agent/features/conversation/presentation/widgets/native_conversation_wave.dart';
import '../../support/pump_ui_transitions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/calls/data/preview_call_flow.dart';
import 'package:phone_agent/features/calls/presentation/pages/call_flow_preview_page.dart';
import 'package:phone_agent/features/calls/presentation/pages/call_session_page.dart';
import 'package:phone_agent/features/conversation/presentation/pages/conversation_page.dart';

Future<void> openMonitor(WidgetTester tester) async {
  await tester.pumpWidget(
    const MaterialApp(
      home: CallFlowPreviewPage(scenario: CallFlowScenario.single),
    ),
  );
  await tester.tap(find.text('发送合成需求'));
  await tester.pump(const Duration(milliseconds: 1));
  await tester.pump();
  await tester.tap(find.text('确认合成拨打'));
  await tester.pump(const Duration(milliseconds: 1500));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 1500));
  await tester.pump();
  await tester.tap(find.bySemanticsLabel('开始监听'));
  await tester.pumpUntilUiSettled();
}

Future<void> action(WidgetTester tester, String label) async {
  await tester.tap(find.text('监听演练'));
  await tester.pumpUntilUiSettled();
  await tester.tap(find.text(label));
  await tester.pumpUntilUiSettled();
}

void main() {
  testWidgets(
    'call overlay preserves a single compact status wave without stage pulse',
    (tester) async {
      await openMonitor(tester);
      final wave = find.byType(NativeConversationWave, skipOffstage: false);
      expect(wave, findsOneWidget);
      expect(
        tester.widget<NativeConversationWave>(wave).mode,
        NativeConversationWaveMode.standby,
      );
      await tester.pump(const Duration(milliseconds: 900));
      expect(wave, findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.byType(CallSessionPage), findsOneWidget);
      expect(find.byType(ConversationPage), findsNothing);
      await tester.tap(find.text('合成远端结束'));
      await tester.pump(const Duration(milliseconds: 1600));
      await tester.pump();
      expect(find.byType(CallSessionPage), findsNothing);
      expect(find.byType(NativeConversationWave), findsOneWidget);
      expect(tester.getSize(wave), const Size(26, 27));
      await tester.pump(const Duration(milliseconds: 900));
      expect(
        tester.widget<NativeConversationWave>(wave).mode,
        NativeConversationWaveMode.standby,
      );
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );
  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets('formal call host monitor/mute/route/terminal at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, width == 320 ? 568 : 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await openMonitor(tester);
      expect(find.text('正在连接监听…'), findsNothing);
      await action(tester, '注入合成PCM');
      expect(find.text('正在监听'), findsNothing);
      expect(find.text('MOCK监听：票据1 / 播放3200字节'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('音源，听筒'));
      await tester.pumpUntilUiSettled();
      await tester.tap(find.text('蓝牙').last);
      await tester.pumpUntilUiSettled();
      expect(find.bySemanticsLabel('音源，蓝牙'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('停止监听'));
      await tester.pumpUntilUiSettled();
      expect(find.text('监听已静音'), findsNothing);
      await action(tester, '注入合成PCM');
      expect(find.text('MOCK监听：票据1 / 播放3200字节'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('开始监听'));
      await tester.pumpUntilUiSettled();
      await action(tester, '移除合成蓝牙');
      await tester.pump(const Duration(seconds: 1));
      expect(find.bySemanticsLabel('音源，听筒'), findsOneWidget);
      await tester.tap(find.text('合成远端结束'));
      await tester.pump(const Duration(milliseconds: 1600));
      await tester.pump();
      expect(find.byType(CallSessionPage), findsNothing);
      expect(find.text('发送合成需求'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'background stops monitor; resume does not restart or request ticket',
    (tester) async {
      await openMonitor(tester);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(find.text('监听已关闭'), findsNothing);
      expect(find.text('MOCK监听：票据1 / 播放0字节'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.byType(CallSessionPage), findsOneWidget);
      expect(find.byType(ConversationPage), findsNothing);
      await tester.pump(const Duration(seconds: 2));
      expect(find.byType(CallSessionPage), findsOneWidget);
      expect(find.text('MOCK监听：票据1 / 播放0字节'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
