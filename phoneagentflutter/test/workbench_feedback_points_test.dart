import 'support/pump_ui_transitions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/feedback/domain/call_evaluation.dart';
import 'package:phone_agent/features/feedback/presentation/widgets/call_evaluation_card.dart';
import 'package:phone_agent/features/feedback/presentation/widgets/task_rating_sheet.dart';
import '../tool/previews/migration_workbench.dart';
import '../tool/previews/workbench_catalog.dart';

void main() {
  for (final width in [320.0, 430.0]) {
    testWidgets('feedback draft, retry, read-only and scene reset at $width', (
      tester,
    ) async {
      await mount(tester, 'feedback', width);
      final semantics = tester.ensureSemantics();
      for (final entry in [('好评', CallRating.good), ('差评', CallRating.bad)]) {
        await tester.tap(find.byTooltip(entry.$1));
        await tester.pumpUntilUiSettled();
        expect(
          tester
              .widget<CallEvaluationCard>(find.byType(CallEvaluationCard))
              .state
              .evaluation!
              .rating,
          entry.$2,
        );
      }
      await tester.tap(find.text('去评分'));
      await tester.pumpUntilUiSettled();
      for (final dimension in [
        'understanding',
        'call',
        'clone',
        'completion',
      ]) {
        final button = find.byKey(ValueKey('rating-$dimension-4'));
        await tester.ensureVisible(button);
        await tester.tap(button);
        await tester.pump();
      }
      await revealSuggestion(tester);
      await tester.enterText(find.byType(TextFormField), '仅内存的验收建议');
      await tester.tap(find.byTooltip('关闭评分'));
      await tester.pumpUntilUiSettled();
      await tester.tap(find.text('去评分'));
      await tester.pumpUntilUiSettled();
      await revealSuggestion(tester);
      expect(find.text('仅内存的验收建议'), findsOneWidget);
      await tester.tap(find.text('提交评价'));
      await tester.pumpUntilUiSettled();
      expect(find.text('评价提交成功'), findsNothing);
      expect(find.text('评价提交失败，请重试'), findsOneWidget);
      await tester.tap(find.text('提交评价'));
      await tester.pumpUntilUiSettled();
      expect(find.text('评价提交成功'), findsOneWidget);
      expect(
        tester.semantics.simulatedAccessibilityTraversal().map((n) => n.label),
        contains('返回目录'),
      );
      await tester.tap(find.text('完成'));
      await tester.pumpUntilUiSettled();
      await tester.tap(find.text('查看'));
      await tester.pumpUntilUiSettled();
      expect(find.text('查看评分'), findsOneWidget);
      expect(find.text('提交评价'), findsNothing);
      // Leave with the nested modal open: the whole scene must be disposable.
      await tester.tap(find.byKey(const ValueKey('workbench-home')));
      await tester.pumpUntilUiSettled();
      await enter(tester, 'feedback');
      expect(find.text('去评分'), findsOneWidget);
      expect(find.text('查看'), findsNothing);
      expect(
        tester
            .widget<CallEvaluationCard>(find.byType(CallEvaluationCard))
            .state
            .evaluation!
            .rating,
        isNull,
      );
      await tester.tap(find.text('去评分'));
      await tester.pumpUntilUiSettled();
      await revealSuggestion(tester);
      expect(find.text('仅内存的验收建议'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('workbench-home')));
      await tester.pumpUntilUiSettled();
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });

    testWidgets('points activate once per scene and dispose at $width', (
      tester,
    ) async {
      await mount(tester, 'points-session', width);
      expect(find.text('合成激活请求：0'), findsOneWidget);
      await tester.tap(find.text('开始会话同步'));
      await tester.pumpUntilUiSettled();
      expect(find.text('合成激活请求：1'), findsOneWidget);
      expect(find.text('今日登录赠送 ✦100 积分已到账'), findsOneWidget);
      expect(find.text('900'), findsWidgets);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpUntilUiSettled();
      await tester.tap(find.text('重新挂载页面'));
      await tester.pumpUntilUiSettled();
      expect(find.text('合成激活请求：1'), findsOneWidget);
      expect(find.text('今日登录赠送 ✦100 积分已到账'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('workbench-home')));
      await tester.pumpUntilUiSettled();
      // A delayed polling interval must not touch disposed providers/notifiers.
      await tester.pump(const Duration(minutes: 2));
      await enter(tester, 'points-session');
      expect(find.text('合成激活请求：0'), findsOneWidget);
      await tester.tap(find.text('开始会话同步'));
      await tester.pumpUntilUiSettled();
      expect(find.text('合成激活请求：1'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('workbench-home')));
      await tester.pumpUntilUiSettled();
      expect(tester.takeException(), isNull);
    });
  }
}

Future<void> mount(WidgetTester tester, String id, double width) async {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MigrationWorkbench(
      scenes: [workbenchScenes.singleWhere((s) => s.id == id)],
    ),
  );
  await enter(tester, id);
}

Future<void> enter(WidgetTester tester, String id) async {
  await tester.tap(find.byKey(ValueKey('scene-$id')));
  await tester.pumpUntilUiSettled();
}

Future<void> revealSuggestion(WidgetTester tester) => tester.scrollUntilVisible(
  find.byType(TextFormField),
  160,
  scrollable: find
      .descendant(
        of: find.byType(TaskRatingSheet),
        matching: find.byType(Scrollable),
      )
      .first,
);
