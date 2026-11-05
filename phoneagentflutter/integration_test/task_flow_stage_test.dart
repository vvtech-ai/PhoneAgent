import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:phone_agent/app/phone_agent_app.dart';
import 'package:phone_agent/features/calls/presentation/pages/call_session_page.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/call_confirmation_card.dart';
import 'package:phone_agent/features/tasks/presentation/pages/tasks_page.dart';
import '../test/support/pump_ui_transitions.dart';
import '../tool/previews/migration_workbench.dart';
import '../tool/previews/shell_conversation_ports.dart';
import '../tool/previews/shell_receipt_seeds.dart';
import '../tool/previews/workbench_catalog.dart';
import 'task_question_stage.dart';

/// Device navigation with isolated ports. This does not validate real calls,
/// media, production accounts or upgrades.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('home conversation list detail restore and terminal receipts', (
    tester,
  ) async {
    final steps = <String>[];
    binding.reportData = {
      'platform': defaultTargetPlatform.name,
      'mode': 'MOCK; in-memory account; no server, SMS, phone or real media',
      'completedSteps': steps,
    };
    await tester.pumpWidget(
      MigrationWorkbench(
        scenes: [workbenchScenes.singleWhere((s) => s.id == 'app')],
      ),
    );
    Future<void> tap(Finder target) async {
      await tester.pumpUntilUiSettled();
      if (target.evaluate().isEmpty) {
        final tasks = find.descendant(
          of: find.byType(TasksPage),
          matching: find.byType(Scrollable),
        );
        if (tasks.evaluate().isNotEmpty) {
          final position = tester.state<ScrollableState>(tasks.first).position;
          position.jumpTo(position.minScrollExtent);
          await tester.pump();
        }
        final detail = find.descendant(
          of: find.byKey(const ValueKey('task-detail-scroll')),
          matching: find.byType(Scrollable),
        );
        await tester.scrollUntilVisible(
          target,
          180,
          scrollable: detail.evaluate().isNotEmpty
              ? detail.first
              : tasks.evaluate().isNotEmpty
              ? tasks.first
              : find.byType(Scrollable).last,
        );
      }
      await tester.ensureVisible(target);
      await tester.pumpUntilUiSettled();
      await tester.tap(target);
      await tester.pumpUntilUiSettled();
      expect(tester.takeException(), isNull);
    }

    Future<void> key(String id) => tap(find.byKey(ValueKey(id)));
    await key('scene-app');
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PhoneAgentApp)),
    );
    final ports = container.read(shellConversationPortsProvider);
    await binding.convertFlutterSurfaceToImage();
    await key('skill-restaurant_booking');
    await key('toggle-text');
    await tester.enterText(
      find.byKey(const ValueKey('conversation-input')),
      '帮我订餐厅',
    );
    await key('send-text');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpUntilUiSettled();
    final session = ports.commands.single.sessionId;
    steps.add('home-to-conversation');
    await key('close-conversation');
    await key('tab-2');
    await key('conversation:$session');
    expect(find.text('任务详情'), findsNothing);
    expect(find.byKey(const ValueKey('close-conversation')), findsOneWidget);
    expect(find.textContaining('合成餐厅甲'), findsOneWidget);
    expect(ports.commands, hasLength(1));
    await binding.takeScreenshot('01-task-detail');
    steps.add('list-to-original-session-detail');
    await tap(find.textContaining('合成餐厅甲'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpUntilUiSettled();
    expect(ports.commands.last.sessionId, session);
    expect(ports.commands, hasLength(2));
    expect(find.text('已收到你的选择。'), findsOneWidget);
    steps.add('same-session-continuation');
    await key('close-conversation');
    await key('conversation:$session');
    expect(find.text('已收到你的选择。'), findsOneWidget);
    await key('close-conversation');
    ports.errors!.statuses[session] = 'EXECUTION_ERROR';
    await key('conversation:$session');
    expect((await ports.restore(session)).detail.status, 'EXECUTION_ERROR');
    await binding.takeScreenshot('03-failed-detail');
    expect(find.byKey(const ValueKey('toggle-text')), findsOneWidget);
    await key('close-conversation');
    steps.add('failed-task-detail-and-restoration-without-replay');
    await key('conversation:closed');
    expect((await ports.restore('closed')).detail.status, 'CLOSED');
    expect(find.byKey(const ValueKey('toggle-text')), findsOneWidget);
    await key('close-conversation');
    steps.add('terminal-restoration');
    await key('conversation:${ShellReceiptSeeds.batchSession}');
    expect(find.text('任务详情'), findsNothing);
    expect(find.byKey(const ValueKey('close-conversation')), findsOneWidget);
    await binding.takeScreenshot('02-batch-detail');
    expect(find.byKey(const ValueKey('toggle-text')), findsOneWidget);
    await key('close-conversation');
    expect(ports.commands, hasLength(2), reason: '查看和恢复不能重放工具');
    steps.add('batch-detail-and-restoration-without-replay');
    await key('tab-0');
    await key('skill-restaurant_booking');
    await key('toggle-text');
    await tester.enterText(
      find.byKey(const ValueKey('conversation-input')),
      '演练单路通话',
    );
    await key('send-text');
    expect(ports.commands, hasLength(3));
    expect(find.byType(CallSessionPage), findsNothing);
    final pendingSession = ports.commands.last.sessionId;
    expect(find.byType(CallConfirmationCard), findsOneWidget);
    await binding.takeScreenshot('04-pending-confirmation');
    await key('close-conversation');
    await key('tab-2');
    await key('conversation:$pendingSession');
    expect(find.byType(CallConfirmationCard), findsOneWidget);
    expect(ports.commands, hasLength(3));
    expect(find.byType(CallSessionPage), findsNothing);
    await key('toggle-text');
    await tester.enterText(
      find.byKey(const ValueKey('conversation-input')),
      '确认拨打',
    );
    await key('send-text');
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpUntilUiSettled();
    expect(ports.commands, hasLength(4));
    expect(ports.commands.last.sessionId, pendingSession);
    expect(ports.commands.last.actionId, 'confirm_call');
    expect(find.byType(CallSessionPage), findsOneWidget);
    await key('call-挂断');
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpUntilUiSettled();
    expect(find.byType(CallSessionPage), findsNothing);
    await key('close-conversation');
    await key('conversation:$pendingSession');
    await binding.takeScreenshot('05-confirmed-call-detail');
    await key('close-conversation');
    steps.add('pending-history-explicit-confirmation-and-mock-call-end');
    await verifyTaskQuestionsStage(tester, ports, key, tap, (name) async {
      await binding.takeScreenshot(name);
    });
    steps.add('natural-question-restore-reply-history-and-copy');
    await key('workbench-home');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpUntilUiSettled();
  });
}
