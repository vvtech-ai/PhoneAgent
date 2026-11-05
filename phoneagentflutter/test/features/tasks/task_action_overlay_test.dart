import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/tasks/domain/task_records.dart';
import 'package:phone_agent/features/tasks/domain/task_page.dart';
import 'package:phone_agent/features/tasks/presentation/controller/task_controller.dart';
import 'package:phone_agent/features/tasks/presentation/pages/tasks_page.dart';
import 'task_pagination_test.dart' show row;

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      '$platform long press keeps row clear, cancels and blocks dialing delete',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final scroll = ScrollController();
        var pins = 0, deletes = 0;
        final records = [
          for (var i = 0; i < 20; i++) row('t$i').copyWith(title: '任务$i'),
        ];
        final blocked = const TaskRecord(
          id: 'blocked',
          kind: TaskRecordKind.conversation,
          title: '通话任务',
          status: TaskStatus.running,
          rawStatus: 'DIALING',
          ref: TaskRef(TaskResourceType.agentConversation, 'blocked'),
          canDelete: false,
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: platform),
            home: Scaffold(
              body: TasksPage(
                state: TaskState(
                  catalog: TaskCatalog([...records, blocked.copyWith()]),
                ),
                scrollController: scroll,
                onRefresh: () async {},
                onOpen: (_) {},
                onPin: (_) => pins++,
                onDelete: (_) => deletes++,
              ),
            ),
          ),
        );
        scroll.jumpTo(500);
        await tester.pump();
        final selected = find.text('AI 通话 · 任务6');
        await tester.longPress(selected);
        await tester.pumpAndSettle();
        expect(find.byType(BackdropFilter), findsOneWidget);
        expect(find.text('AI 通话 · 任务6'), findsNWidgets(2));
        expect(tester.getRect(find.text('删除')).bottom, lessThanOrEqualTo(552));
        await tester.tap(find.text('删除'));
        await tester.pumpAndSettle();
        expect(find.text('删除任务？'), findsOneWidget);
        expect(find.text('删除后，你将无法再查看此任务。'), findsOneWidget);
        await tester.tap(find.text('取消'));
        await tester.pumpAndSettle();
        expect(find.text('置顶'), findsOneWidget);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(scroll.offset, 500);
        expect([pins, deletes], [0, 0]);
        scroll.jumpTo(scroll.position.maxScrollExtent);
        await tester.pump();
        await tester.longPress(find.text('AI 通话 · 通话任务'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('删除'));
        await tester.pumpAndSettle();
        expect(find.text('任务正在拨打中，暂时无法删除'), findsOneWidget);
        await tester.tap(find.text('知道了'));
        await tester.pumpAndSettle();
        expect(deletes, 0);
        await tester.pumpWidget(const SizedBox());
        scroll.dispose();
        expect(tester.takeException(), isNull);
      },
    );
  }
}
