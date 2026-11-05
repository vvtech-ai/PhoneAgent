import 'support/pump_ui_transitions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/phone_agent_app.dart';
import 'package:phone_agent/features/auth/presentation/controller/auth_providers.dart';
import 'package:phone_agent/features/feedback/domain/call_evaluation.dart';
import 'package:phone_agent/features/feedback/presentation/widgets/call_evaluation_card.dart';
import 'package:phone_agent/features/feedback/presentation/widgets/task_rating_sheet.dart';
import '../tool/previews/auth_scenario.dart';
import '../tool/previews/migration_workbench.dart';
import '../tool/previews/shell_conversation_ports.dart';
import '../tool/previews/shell_receipt_preview.dart';
import '../tool/previews/shell_receipt_seeds.dart';
import '../tool/previews/workbench_catalog.dart';

void main() {
  for (final width in [320.0, 430.0]) {
    testWidgets(
      'receipt audio and per-target feedback through formal routes $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final previousHitTestPolicy =
            WidgetController.hitTestWarningShouldBeFatal;
        WidgetController.hitTestWarningShouldBeFatal = true;
        addTearDown(() {
          WidgetController.hitTestWarningShouldBeFatal = previousHitTestPolicy;
        });
        await tester.pumpWidget(
          MigrationWorkbench(
            scenes: [workbenchScenes.singleWhere((s) => s.id == 'app')],
          ),
        );
        Future<void> settle() async {
          await tester.pump();
          if (find.text('MOCK · 保存本次录音').evaluate().isNotEmpty) {
            // Saving stays busy until the external destination dialog resolves.
            await tester.pump(const Duration(milliseconds: 350));
          } else {
            await tester.pumpUntilUiSettled();
          }
          expect(tester.takeException(), isNull);
        }

        Future<void> tap(Finder target) async {
          await settle();
          if (target.evaluate().isEmpty) {
            await tester.scrollUntilVisible(
              target,
              220,
              scrollable:
                  find
                      .byKey(const ValueKey('conversation-timeline'))
                      .evaluate()
                      .isEmpty
                  ? find.byType(Scrollable).last
                  : find
                        .descendant(
                          of: find.byKey(
                            const ValueKey('conversation-timeline'),
                          ),
                          matching: find.byType(Scrollable),
                        )
                        .first,
            );
          }
          await Scrollable.ensureVisible(
            tester.element(target),
            alignment: .35,
          );
          await settle();
          await tester.tap(target);
          await settle();
        }

        Future<void> key(String id) => tap(find.byKey(ValueKey(id)));
        Future<void> text(String value) => tap(find.text(value));
        Future<void> tooltip(String value) => tap(find.byTooltip(value));
        Future<void> open(String session) async {
          await key('conversation:$session');
        }

        Future<void> suggestion() => tester.scrollUntilVisible(
          find.byType(TextFormField),
          160,
          scrollable: find
              .descendant(
                of: find.byType(TaskRatingSheet),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        CallRating? rating() => tester
            .widget<CallEvaluationCard>(find.byType(CallEvaluationCard))
            .state
            .evaluation!
            .rating;

        await settle();
        await key('scene-app');
        final container = ProviderScope.containerOf(
          tester.element(find.byType(PhoneAgentApp)),
        );
        final ports = container.read(shellFeedbackPortsProvider);
        final agent = container.read(shellConversationPortsProvider);
        final auth = container.read(sessionStoreProvider) as AuthScenario;
        await key('tab-2');
        await open(ShellReceiptSeeds.singleSession);
        expect(find.text('去评分'), findsOneWidget);
        await tooltip('好评');
        expect(rating(), CallRating.good);
        await tooltip('播放录音');
        expect(find.byTooltip('暂停录音'), findsOneWidget);
        await tooltip('暂停录音');
        await tooltip('保存录音');
        await text('取消保存');
        expect(find.text('录音已保存'), findsNothing);
        await tooltip('保存录音');
        await text('模拟保存');
        await tester.pump(); // Paint the post-frame transient save notice.
        expect(find.text('录音已保存'), findsOneWidget);
        await text('去评分');
        for (final dimension in [
          'understanding',
          'call',
          'clone',
          'completion',
        ]) {
          await key('rating-$dimension-4');
        }
        await suggestion();
        await tester.enterText(find.byType(TextFormField), '只属于单路回执的建议');
        await tooltip('关闭评分');
        await key('close-conversation');

        await open(ShellReceiptSeeds.batchSession);
        expect(find.text('去评分'), findsNothing);
        expect(rating(), isNull);
        await tooltip('差评');
        expect(rating(), CallRating.bad);
        await key('receipt-transcript:one');
        expect(find.text('确认参加会议。'), findsOneWidget);
        await tooltip('播放本次电话录音');
        await tooltip('暂停本次电话录音');
        await key('close-conversation');

        await open(ShellReceiptSeeds.singleSession);
        expect(rating(), CallRating.good);
        await text('去评分');
        await suggestion();
        expect(find.text('只属于单路回执的建议'), findsOneWidget);
        await text('提交评价');
        expect(find.text('评价提交失败，请重试'), findsOneWidget);
        await text('提交评价');
        expect(find.text('评价提交成功'), findsOneWidget);
        expect(ports.submitKeys, hasLength(2));
        expect(ports.submitKeys.toSet(), hasLength(1), reason: '失败重试沿用幂等键');
        await tap(find.widgetWithText(FilledButton, '完成'));
        await key('close-conversation');
        await open(ShellReceiptSeeds.singleSession);
        await text('查看');
        expect(find.text('查看评分'), findsOneWidget);
        expect(find.text('提交评价'), findsNothing);
        await tooltip('关闭评分');
        await key('close-conversation');
        await open(ShellReceiptSeeds.batchSession);
        expect(rating(), CallRating.bad);
        expect(find.text('查看'), findsNothing);
        await key('close-conversation');
        expect(agent.commands, isEmpty, reason: '查看回执不能重发Agent或电话');

        await key('tab-3');
        await key('settings-logout');
        await text('退出');
        await tester.enterText(
          find.byKey(const ValueKey('loginPhone')),
          '13800000000',
        );
        await tester.enterText(find.byKey(const ValueKey('loginCode')), '123456');
        await key('loginAgreement');
        await key('loginBtn');
        expect(container.read(shellFeedbackPortsProvider), isNot(same(ports)));
        await key('tab-2');
        await open(ShellReceiptSeeds.singleSession);
        expect(rating(), isNull);
        expect(find.text('去评分'), findsOneWidget);
        expect(auth.sends, 0);
        await key('workbench-home');
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 20));
        await settle();
      },
    );
  }
}
