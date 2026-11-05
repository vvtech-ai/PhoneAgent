import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/home/domain/home_defaults.dart';
import 'package:phone_agent/features/home/presentation/controller/home_controller.dart';
import 'package:phone_agent/features/home/presentation/pages/home_page.dart';
import 'package:phone_agent/features/shell/presentation/widgets/floating_navigation.dart';
import 'package:phone_agent/features/task_notifications/domain/home_notification.dart';
import 'package:phone_agent/features/task_notifications/presentation/widgets/home_notification_banner.dart';
import 'package:phone_agent/features/tasks/domain/task_records.dart';

HomeNotification item(TaskStatus status) => HomeNotification(
  id: 'legacy_task:synthetic',
  text: '合成任务 ${status.name}：完整任务说明',
  record: TaskRecord(
    id: 'synthetic',
    taskId: 'synthetic',
    title: '合成任务',
    kind: TaskRecordKind.legacyTask,
    rawStatus: status.name,
    status: status,
  ),
);

List<SemanticsNode> nodes(WidgetTester tester) {
  final result = <SemanticsNode>[];
  void visit(SemanticsNode node) {
    result.add(node);
    node.visitChildren((child) {
      visit(child);
      return true;
    });
  }

  visit(
    tester.binding.renderViews.single.owner!.semanticsOwner!.rootSemanticsNode!,
  );
  return result;
}

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final large in [false, true]) {
      testWidgets(
        '$platform notification actions states counter large=$large',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = large
              ? const Size(320, 568)
              : const Size(393, 820);
          addTearDown(tester.view.reset);
          final semantics = tester.ensureSemantics();
          var status = TaskStatus.completed, busy = false;
          var opens = 0, closes = 0, selected = -1;
          late StateSetter update;
          try {
            await tester.pumpWidget(
              MaterialApp(
                theme: ThemeData(platform: platform),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(large ? 2 : 1)),
                  child: child!,
                ),
                home: Scaffold(
                  body: StatefulBuilder(
                    builder: (context, setState) {
                      update = setState;
                      return Column(
                        children: [
                          HomeNotificationBanner(
                            item: item(status),
                            pendingCount: 125,
                            busy: busy,
                            onOpen: () => opens++,
                            onDismiss: () => closes++,
                            onRetry: () {},
                          ),
                          const Spacer(),
                          FloatingNavigation(
                            selected: 0,
                            taskBadgeCount: 125,
                            onSelected: (value) => selected = value,
                            onDial: () {},
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            );
            final colors = [
              const Color(0xFFEBF5FF),
              const Color(0xFFFFF7ED),
              const Color(0xFFEFF6FF),
              const Color(0xFFFEF2F2),
            ];
            for (final (index, value) in TaskStatus.values.indexed) {
              update(() => status = value);
              await tester.pump();
              final decoration =
                  tester
                          .widget<Container>(
                            find.byKey(
                              const ValueKey('home-task-notification'),
                            ),
                          )
                          .decoration!
                      as BoxDecoration;
              expect(decoration.color, colors[index]);
              final open = nodes(tester)
                  .singleWhere((n) => n.label.startsWith('合成任务 '))
                  .getSemanticsData();
              expect(open.hasFlag(SemanticsFlag.isButton), isTrue);
              expect(open.label, contains('还有 124 条'));
              final close = nodes(
                tester,
              ).singleWhere((n) => n.label == '关闭当前通知').getSemanticsData();
              expect(close.hasAction(SemanticsAction.tap), isTrue);
              expect(
                tester
                    .getSize(
                      find.byKey(const ValueKey('home-notification-dismiss')),
                    )
                    .shortestSide,
                greaterThanOrEqualTo(48),
              );
              await tester.tap(
                find.byKey(const ValueKey('home-notification-open')),
              );
              await tester.tap(
                find.byKey(const ValueKey('home-notification-dismiss')),
              );
            }
            expect(opens, 4);
            expect(closes, 4);
            expect(find.text('99'), findsOneWidget);
            final tab = nodes(
              tester,
            ).singleWhere((n) => n.label == '任务，125 条未读通知').getSemanticsData();
            expect(tab.hasFlag(SemanticsFlag.isButton), isTrue);
            await tester.tap(find.byKey(const ValueKey('tab-2')));
            expect(selected, 2);
            update(() => busy = true);
            await tester.pump();
            expect(
              nodes(tester)
                  .singleWhere((n) => n.label == '关闭当前通知')
                  .getSemanticsData()
                  .hasAction(SemanticsAction.tap),
              isFalse,
            );
            expect(tester.takeException(), isNull);
          } finally {
            await tester.pumpWidget(const SizedBox());
            semantics.dispose();
          }
        },
      );

      testWidgets(
        '$platform home header stays fixed and large screen scrolls large=$large',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = large
              ? const Size(320, 568)
              : const Size(393, 820);
          addTearDown(tester.view.reset);
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(platform: platform),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(large ? 2 : 1)),
                child: child!,
              ),
              home: Scaffold(
                body: HomePage(
                  state: const HomeState(),
                  modelName: '合成模型',
                  onModels: () {},
                  onEntry: (_) {},
                  onRefresh: () async {},
                  notification: HomeNotificationBanner(
                    item: item(TaskStatus.completed),
                    pendingCount: 125,
                    onOpen: () {},
                    onDismiss: () {},
                    onRetry: () {},
                  ),
                ),
              ),
            ),
          );
          final before = tester.getRect(find.text('PhoneAgent'));
          final banner = tester.getRect(
            find.byKey(const ValueKey('home-task-notification')),
          );
          await tester.drag(
            find.byType(CustomScrollView),
            const Offset(0, -400),
          );
          await tester.pumpAndSettle();
          if (!large) {
            expect(tester.getRect(find.text('PhoneAgent')), before);
            expect(
              tester.getRect(
                find.byKey(const ValueKey('home-task-notification')),
              ),
              banner,
            );
          }
          await tester.scrollUntilVisible(
            find.byKey(ValueKey('skill-${builtinHome.cards.last.id}')),
            200,
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
