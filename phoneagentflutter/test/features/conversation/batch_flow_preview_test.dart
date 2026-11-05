import '../../support/pump_ui_transitions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/presentation/pages/batch_flow_preview_page.dart';

void main() {
  testWidgets(
    'shared page receives progress then final without duplicate cards',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: BatchFlowPreviewPage()));
      await tester.tap(find.text('进入统一页并发送合成需求'));
      await tester.pumpUntilUiSettled();
      expect(find.textContaining('0/3 已产生结果'), findsOneWidget);
      await tester.tap(find.text('推送逐项进度'));
      await tester.pumpUntilUiSettled();
      expect(find.textContaining('1/3 已产生结果'), findsOneWidget);
      await tester.tap(find.text('推送最终结果'));
      await tester.pumpUntilUiSettled();
      expect(find.textContaining('3/3 已产生结果'), findsOneWidget);
      expect(find.text('合成批量已汇总，无真实电话或费用'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'exit retains receive-only stream and final can be restored without a new call',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: BatchFlowPreviewPage()));
      await tester.tap(find.text('进入统一页并发送合成需求'));
      await tester.pumpUntilUiSettled();
      await tester.tap(find.byKey(const ValueKey('close-conversation')));
      await tester.pumpUntilUiSettled();
      expect(find.text('活动接收：1'), findsOneWidget);
      await tester.tap(find.text('模拟退出后结果到达'));
      await tester.pumpUntilUiSettled();
      expect(find.text('活动接收：0'), findsOneWidget);
      await tester.tap(find.text('从合成任务列表恢复'));
      await tester.pumpUntilUiSettled();
      expect(find.textContaining('3/3 已产生结果'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
