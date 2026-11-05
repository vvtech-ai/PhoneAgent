import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/tasks/domain/task_records.dart';
import 'package:phone_agent/features/tasks/presentation/controller/task_controller.dart';
import 'package:phone_agent/features/tasks/presentation/pages/tasks_page.dart';
import 'task_pinned_visibility_test.dart' show row;

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      '$platform v66 fold follows unread pins and four page footer states',
      (tester) async {
        final records = [row('未读置顶', pinned: true, unread: true), row('普通任务')];
        Future<void> show(TaskState state) => tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: platform),
            home: Scaffold(
              body: TasksPage(
                state: state,
                onRefresh: () async {},
                onOpen: (_) {},
                onLoadMore: () {},
                pinnedCollapsed: true,
                pinnedCount: 1,
                onTogglePinned: () {},
                onClearUnread: () {},
              ),
            ),
          ),
        );
        await show(
          TaskState(
            catalog: TaskCatalog(records),
            hasMore: true,
            hasUnread: true,
          ),
        );
        expect(find.text('继续上滑，加载更多任务'), findsOneWidget);
        final foldY = tester.getCenter(find.text('1 个置顶任务')).dy;
        expect(tester.getCenter(find.text('AI 通话 · 未读置顶')).dy, lessThan(foldY));
        expect(
          tester.getCenter(find.text('AI 通话 · 普通任务')).dy,
          greaterThan(foldY),
        );
        expect(find.byKey(const ValueKey('task-unread-dot')), findsOneWidget);
        expect(find.byKey(const ValueKey('task-pinned-icon')), findsOneWidget);
        expect(find.bySemanticsLabel('清空所有未读状态'), findsOneWidget);
        await show(
          TaskState(
            catalog: TaskCatalog(records),
            hasMore: true,
            moreFailed: true,
          ),
        );
        expect(find.text('加载失败，点击重试'), findsOneWidget);
        await show(
          TaskState(
            catalog: TaskCatalog(records),
            hasMore: true,
            loadingMore: true,
          ),
        );
        expect(find.text('正在加载…'), findsOneWidget);
        await show(TaskState(catalog: TaskCatalog(records)));
        expect(find.text('已显示全部任务'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }
}
