import '../../support/pump_ui_transitions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/tasks/presentation/pages/task_record_card.dart';
import 'package:phone_agent/features/conversation/presentation/pages/conversation_route.dart';
import 'package:phone_agent/features/translation_history/presentation/pages/translation_history_route.dart';
import '../../../tool/previews/shell_preview.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final translation in [false, true]) {
      testWidgets(
        '$platform task named entry only opens once translation=$translation',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = const Size(393, 820);
          addTearDown(tester.view.reset);
          final semantics = tester.ensureSemantics();
          try {
            await tester.pumpWidget(const ShellPreviewPage());
            await tester.pumpUntilUiSettled();
            await tester.tap(find.byKey(const ValueKey('tab-2')));
            await tester.pumpUntilUiSettled();
            final card = find.byKey(
              ValueKey(
                translation
                    ? 'call:translation'
                    : 'conversation:mock-receipt-single',
              ),
            );
            await tester.ensureVisible(card);
            await tester.pumpUntilUiSettled();
            final callback = tester.widget<TaskRecordCard>(card).onTap;
            callback();
            callback();
            await tester.pumpUntilUiSettled();
            final page = translation
                ? find.byType(TranslationHistoryRoute, skipOffstage: false)
                : find.byType(ConversationRoute, skipOffstage: false);
            expect(page, findsOneWidget);
            if (!translation) {
              expect(find.text('任务详情'), findsNothing);
              expect(
                find.byKey(const ValueKey('task-detail-restore')),
                findsNothing,
              );
            }
            callback(); // A cached entrance must not push from behind the detail.
            await tester.pumpUntilUiSettled();
            expect(page, findsOneWidget);
            Future<void> close() async {
              await tester.tap(
                translation
                    ? find.byTooltip('关闭翻译记录')
                    : find.byKey(const ValueKey('close-conversation')),
              );
              await tester.pumpUntilUiSettled();
              expect(page, findsNothing);
              expect(find.byKey(const ValueKey('tab-2')), findsOneWidget);
            }

            await close();
            final nodes = <SemanticsNode>[];
            void visit(SemanticsNode node) {
              nodes.add(node);
              node.visitChildren((child) {
                visit(child);
                return true;
              });
            }

            visit(
              tester
                  .binding
                  .renderViews
                  .single
                  .owner!
                  .semanticsOwner!
                  .rootSemanticsNode!,
            );
            final label = translation ? '合成翻译对象' : '会议通知 · MOCK · 单路回执与评分';
            final data = nodes
                .singleWhere((node) => node.label.startsWith(label))
                .getSemanticsData();
            expect(data.hasFlag(SemanticsFlag.isButton), isTrue);
            expect(data.hasFlag(SemanticsFlag.isEnabled), isTrue);
            expect(data.hasAction(SemanticsAction.tap), isTrue);
            expect(data.label, contains(translation ? '00:12' : '已完成'));
            callback();
            await tester.pumpUntilUiSettled();
            expect(page, findsOneWidget);
            await close();
            expect(tester.takeException(), isNull);
          } finally {
            await tester.pumpWidget(const SizedBox());
            await tester.pumpUntilUiSettled();
            semantics.dispose();
          }
        },
        variant: TargetPlatformVariant({platform}),
      );
    }
  }
}
