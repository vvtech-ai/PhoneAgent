import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/tasks/domain/task_records.dart';
import 'package:phone_agent/features/tasks/presentation/controller/task_controller.dart';
import 'package:phone_agent/features/tasks/presentation/pages/tasks_page.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('long task remains readable and opens once on $platform', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var opens = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: platform),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: TasksPage(
              state: TaskState(
                catalog: TaskCatalog([
                  const TaskRecord(
                    id: 'long-task',
                    kind: TaskRecordKind.conversation,
                    title: '很长的历史任务名称用于检查窄屏和动态字体',
                    summary: '完整说明在状态下面使用卡片可用宽度显示',
                    status: TaskStatus.executionError,
                    rawStatus: 'ERROR',
                  ),
                ]),
              ),
              onRefresh: () async {},
              onOpen: (_) => opens++,
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('执行异常'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('long-task')));
      expect(opens, 1);
    });
  }
  for (final sample in {
    -1000: '00:00',
    0: '00:00',
    12000: '00:12',
    170000: '02:50',
    3661000: '01:01:01',
  }.entries) {
    testWidgets('translation duration ${sample.key} renders ${sample.value}', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TasksPage(
              state: TaskState(
                catalog: TaskCatalog([
                  TaskRecord(
                    id: 'duration',
                    kind: TaskRecordKind.translation,
                    title: '合成记录',
                    status: TaskStatus.completed,
                    rawStatus: 'ENDED',
                    durationMillis: sample.key,
                  ),
                ]),
              ),
              onRefresh: () async {},
              onOpen: (_) {},
            ),
          ),
        ),
      );
      expect(find.text(sample.value), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
