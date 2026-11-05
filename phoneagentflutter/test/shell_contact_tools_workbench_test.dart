import 'support/pump_ui_transitions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/phone_agent_app.dart';
import 'package:phone_agent/features/auth/presentation/controller/auth_providers.dart';
import 'package:phone_agent/features/conversation/domain/agent_protocol.dart';
import '../tool/previews/auth_scenario.dart';
import '../tool/previews/migration_workbench.dart';
import '../tool/previews/shell_conversation_ports.dart';
import '../tool/previews/workbench_catalog.dart';

void main() {
  for (final width in [320.0, 430.0]) {
    testWidgets('contact tool continuation and candidate restore $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MigrationWorkbench(
          scenes: [workbenchScenes.singleWhere((s) => s.id == 'app')],
        ),
      );
      Future<void> tap(Finder finder) async {
        await tester.pumpUntilUiSettled();
        await tester.ensureVisible(finder);
        await tester.tap(finder, warnIfMissed: true);
        await tester.pumpUntilUiSettled();
        expect(tester.takeException(), isNull);
      }

      Future<void> key(String value) => tap(find.byKey(ValueKey(value)));
      Future<void> send(String value) async {
        if (find
            .byKey(const ValueKey('conversation-input'))
            .evaluate()
            .isEmpty) {
          await key('toggle-text');
        }
        await tester.enterText(
          find.byKey(const ValueKey('conversation-input')),
          value,
        );
        await tester.pump();
        await key('send-text');
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpUntilUiSettled();
        expect(tester.takeException(), isNull);
      }

      await key('scene-app');
      final container = ProviderScope.containerOf(
        tester.element(find.byType(PhoneAgentApp)),
      );
      final ports = container.read(shellConversationPortsProvider);
      final auth = container.read(sessionStoreProvider) as AuthScenario;
      await key('skill-restaurant_booking');
      await send('按号码查询联系人');
      expect(ports.phoneResults, hasLength(1));
      expect(ports.phoneResults.single['displayName'], '演示联系人');
      expect(find.text('MOCK · 号码查询：演示联系人；未拨号。'), findsOneWidget);
      final session = ports.commands.single.sessionId;
      await send('按姓名查询联系人');
      expect(ports.nameResults, hasLength(1));
      expect(ports.nameResults.single.single['inputSource'], 'typed');
      expect(ports.nameResults.single.single['status'], 'MULTIPLE_CANDIDATES');
      expect(find.textContaining('2025550102'), findsOneWidget);
      await key('close-conversation');
      await key('tab-2');
      await key('conversation:$session');
      expect(ports.commands, hasLength(2));
      expect(ports.phoneResults, hasLength(1));
      expect(ports.nameResults, hasLength(1));
      expect(find.textContaining('2025550102'), findsOneWidget);
      await tap(find.textContaining('2025550102'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpUntilUiSettled();
      expect(ports.commands, hasLength(3));
      expect(ports.commands.last.message, '第 2 个');
      expect(
        ports.commands.last.pendingToolCallId,
        startsWith('contacts:lookup:'),
      );
      expect(find.text('已收到你的选择。'), findsOneWidget);
      await key('close-conversation');
      await key('conversation:$session');
      expect(find.text('已收到你的选择。'), findsOneWidget);
      expect(ports.commands, hasLength(3));
      expect((await ports.restore(session)).pendingTool, isNull);
      expect(auth.sends, 0);
      await key('close-conversation');
      final logout = container
          .read(sessionControllerProvider.notifier)
          .signOut();
      await tester.pumpUntilUiSettled();
      await logout;
      final next = container.read(shellConversationPortsProvider);
      expect(next, isNot(same(ports)));
      expect(next.phoneResults, isEmpty);
      expect(next.nameResults, isEmpty);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpUntilUiSettled();
    });
  }

  test('lookup continuation rejects wrong context and closed ports', () async {
    final ports = ShellConversationPorts();
    await ports
        .start(
          const AgentCommand(
            sessionId: 's',
            userId: 'synthetic',
            commandId: 'c',
            idempotencyKey: 'c',
            traceId: 'c',
            message: '按号码查询联系人',
          ),
        )
        .events
        .drain<void>();
    for (final context in [('other', 'lookup:c'), ('s', 'other')]) {
      await expectLater(
        ports.submit(
          sessionId: context.$1,
          toolCallId: context.$2,
          result: {'found': false},
        ),
        throwsStateError,
      );
    }
    expect(ports.phoneResults, isEmpty);
    ports.close();
    await expectLater(
      ports.submit(
        sessionId: 's',
        toolCallId: 'lookup:c',
        result: {'found': false},
      ),
      throwsStateError,
    );
    expect(ports.phoneResults, isEmpty);
  });
}
