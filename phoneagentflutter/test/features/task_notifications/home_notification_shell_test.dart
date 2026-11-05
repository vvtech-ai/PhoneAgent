import '../../support/pump_ui_transitions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/home_notification_providers.dart';
import 'package:phone_agent/features/task_notifications/presentation/widgets/home_notification_banner.dart';
import 'package:phone_agent/features/shell/presentation/pages/shell_route.dart';
import 'package:phone_agent/features/tasks/domain/task_records.dart';
import '../../../tool/previews/shell_preview.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      '$platform hides home task banner and tab count while retaining task reads',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(393, 820);
        addTearDown(tester.view.reset);
        await tester.pumpWidget(const ShellPreviewPage());
        await tester.pumpUntilUiSettled();
        final element = tester.element(find.byType(ShellRoute));
        final container = ProviderScope.containerOf(element);
        final controller = container.read(
          homeNotificationControllerProvider.notifier,
        );
        final original = container
            .read(homeNotificationControllerProvider)
            .pending;
        expect(original.length, greaterThan(1));
        expect(find.byType(HomeNotificationBanner), findsNothing);
        expect(find.byKey(const ValueKey('task-unread-badge')), findsNothing);
        await tester.tap(find.byKey(const ValueKey('tab-2')));
        await tester.pumpUntilUiSettled();
        expect(
          container.read(homeNotificationControllerProvider).pending,
          isEmpty,
        );
        expect(find.byKey(const ValueKey('task-unread-badge')), findsNothing);
        await tester.tap(find.byKey(const ValueKey('tab-0')));
        await tester.pumpUntilUiSettled();
        expect(
          find.byKey(const ValueKey('home-task-notification')),
          findsNothing,
        );
        expect(
          container.read(homeNotificationControllerProvider).pending,
          isEmpty,
        );
        controller.replaceRecords([
          ...original.map((item) => item.record),
          const TaskRecord(
            id: 'conversation:future',
            sessionId: 'future',
            kind: TaskRecordKind.conversation,
            title: '合成新增任务',
            rawStatus: 'COMPLETED',
            status: TaskStatus.completed,
          ),
        ]);
        await tester.pumpUntilUiSettled();
        expect(
          container.read(homeNotificationControllerProvider).pending.single.id,
          'conversation:future',
        );
        expect(
          find.byKey(const ValueKey('home-task-notification')),
          findsNothing,
        );
        await tester.tap(find.byKey(const ValueKey('tab-2')));
        await tester.pumpUntilUiSettled();
        expect(
          container.read(homeNotificationControllerProvider).pending,
          isEmpty,
        );
        await tester.pumpWidget(const SizedBox());
        await tester.pumpUntilUiSettled();
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant({platform}),
    );
  }
}
