import 'package:flutter/material.dart';
import 'package:phone_agent/features/tasks/domain/task_record_presentation.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/tasks/domain/task_records.dart';
import 'package:phone_agent/features/tasks/presentation/controller/task_controller.dart';
import 'package:phone_agent/features/tasks/presentation/pages/task_record_card.dart';
import 'package:phone_agent/features/tasks/presentation/pages/task_sync_surface.dart';
import 'package:phone_agent/features/tasks/presentation/pages/tasks_page.dart';

const record = TaskRecord(
  id: 'synthetic',
  kind: TaskRecordKind.conversation,
  title: '合成任务标题',
  summary: '合成任务说明',
  status: TaskStatus.completed,
  rawStatus: 'COMPLETED',
);
void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final large in [false, true]) {
      testWidgets(
        '$platform task loading cached failure retry compact card large=$large',
        (tester) async {
          tester.view.physicalSize = const Size(320, 568);
          tester.view.devicePixelRatio = 1;
          if (large) {
            tester.platformDispatcher.textScaleFactorTestValue = 2;
          }
          addTearDown(tester.view.reset);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final semantics = tester.ensureSemantics();
          var retries = 0;
          Future<void> show(TaskState state) => tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: TasksPage(
                  state: state,
                  onRefresh: () async {
                    retries++;
                  },
                  onOpen: (_) {},
                ),
              ),
            ),
          );
          try {
            await show(const TaskState(loading: true));
            expect(find.byType(LinearProgressIndicator), findsNothing);
            expect(find.text('正在加载任务'), findsOneWidget);
            expect(
              tester.getSize(find.byType(CircularProgressIndicator)),
              const Size(28, 28),
            );
            final listRect = tester.getRect(find.byType(RefreshIndicator));
            final loadingRect = tester.getRect(find.byType(TaskInitialLoading));
            expect(loadingRect.center.dy, closeTo(listRect.center.dy, 1));
            final refresh = const TaskState(
              loading: true,
              catalog: TaskCatalog([record]),
            );
            await show(refresh);
            await tester.pumpAndSettle();
            expect(find.byType(TaskInitialLoading), findsNothing);
            expect(find.text('正在同步...'), findsOneWidget);
            expect(find.byType(TaskRecordCard), findsOneWidget);
            final blue = tester.widget<Material>(
              find
                  .descendant(
                    of: find.byType(TaskSyncSurface),
                    matching: find.byType(Material),
                  )
                  .first,
            );
            expect(blue.color, const Color(0xFFEFF6FF));
            expect(
              tester
                  .getSemantics(find.bySemanticsLabel('正在同步...，任务列表会自动更新'))
                  .hasFlag(SemanticsFlag.isButton),
              isFalse,
            );
            const failed = TaskCatalog(
              [record],
              failedSources: {TaskSource.calls},
            );
            for (final busy in [true, false]) {
              await show(TaskState(loading: busy, catalog: failed));
              await tester.pumpAndSettle();
              final action = find.bySemanticsLabel(
                '同步失败，点击重试，部分任务同步失败（保留上次数据）',
              );
              final node = tester.getSemantics(action);
              expect(node.hasFlag(SemanticsFlag.isButton), isTrue);
              expect(node.hasFlag(SemanticsFlag.isEnabled), !busy);
              expect(
                node.getSemanticsData().hasAction(SemanticsAction.tap),
                !busy,
              );
              expect(find.byType(TaskRecordCard), findsOneWidget);
              await tester.tap(action);
              expect(retries, busy ? 0 : 1);
            }
            await show(const TaskState(catalog: TaskCatalog([record])));
            await tester.pumpAndSettle();
            expect(find.byType(TaskSyncSurface), findsNothing);
            expect(
              tester
                  .widget<Text>(find.text(TaskRecordPresentation.title(record)))
                  .maxLines,
              large ? 2 : 1,
            );
            if (!large) {
              expect(tester.getSize(find.byType(TaskRecordCard)).height, 77);
            }
            expect(
              tester.getSemantics(find.byType(TaskRecordCard)).label,
              contains('任务信息已同步'),
            );
            expect(tester.takeException(), isNull);
          } finally {
            await tester.pumpWidget(const SizedBox());
            semantics.dispose();
          }
        },
        variant: TargetPlatformVariant({platform}),
      );
    }
  }
  testWidgets(
    'initial progress supports reduced motion and releases on disposal',
    (tester) async {
      Future<void> show({bool reduced = false, bool active = true}) =>
          tester.pumpWidget(
            MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(disableAnimations: reduced),
                child: TickerMode(
                  enabled: active,
                  child: const Scaffold(body: TaskInitialLoading()),
                ),
              ),
            ),
          );
      await show(reduced: true);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<CircularProgressIndicator>(
              find.byType(CircularProgressIndicator),
            )
            .value,
        isNotNull,
      );
      await show(active: false);
      await tester.pump(const Duration(seconds: 2));
      expect(tester.binding.transientCallbackCount, 0);
      await show();
      await tester.pump(const Duration(milliseconds: 420));
      expect(find.text('正在加载任务'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
      expect(tester.takeException(), isNull);
    },
  );
}
