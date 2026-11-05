import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/tasks/domain/task_records.dart';
import 'package:phone_agent/features/tasks/presentation/controller/task_controller.dart';
import 'package:phone_agent/features/tasks/presentation/pages/tasks_page.dart';
import 'task_pinned_visibility_test.dart' show row;

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      '$platform bottom loads automatically, failures require retry',
      (tester) async {
        var requests = 0;
        Future<void> show(TaskState state) => tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: platform),
            home: Scaffold(
              body: TasksPage(
                state: state,
                onRefresh: () async {},
                onOpen: (_) {},
                onLoadMore: () => requests++,
              ),
            ),
          ),
        );
        final rows = [for (var i = 0; i < 20; i++) row('任务$i')];
        final state = TaskState(catalog: TaskCatalog(rows), hasMore: true);
        await show(state);
        await tester.pumpAndSettle();
        expect(requests, 0);
        await tester.drag(find.byType(ListView), const Offset(0, -4000));
        await tester.pumpAndSettle();
        expect(requests, 1);
        await tester.drag(find.byType(ListView), const Offset(0, -200));
        await tester.pumpAndSettle();
        expect(requests, 1);
        await show(state.copy(loadingMore: true));
        await tester.pump();
        expect(requests, 1);
        await show(state.copy(moreFailed: true));
        await tester.pumpAndSettle();
        expect(requests, 1);
        await tester.tap(find.text('加载失败，点击重试'));
        expect(requests, 2);
        await show(state.copy(hasMore: false));
        await tester.pumpAndSettle();
        expect(requests, 2);
        await tester.pumpWidget(const SizedBox());
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets(
      '$platform short page and refresh completion load the visible footer',
      (tester) async {
        var requests = 0;
        final state = TaskState(
          catalog: TaskCatalog([row('短页')]),
          hasMore: true,
        );
        Future<void> show(TaskState value) => tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: platform),
            home: Scaffold(
              body: TasksPage(
                state: value,
                onRefresh: () async {},
                onOpen: (_) {},
                onLoadMore: () => requests++,
              ),
            ),
          ),
        );
        await show(state.copy(loading: true));
        await tester.pump();
        expect(requests, 0);
        await show(state);
        await tester.pumpAndSettle();
        expect(requests, 1);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
