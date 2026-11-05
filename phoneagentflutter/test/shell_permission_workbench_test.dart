import 'support/pump_ui_transitions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/phone_agent_app.dart';
import 'package:phone_agent/features/auth/presentation/controller/auth_providers.dart';
import 'package:phone_agent/features/conversation/domain/agent_protocol.dart';
import '../tool/previews/auth_scenario.dart';
import '../tool/previews/migration_workbench.dart';
import '../tool/previews/shell_conversation_ports.dart';
import '../tool/previews/shell_permission_ports.dart';
import '../tool/previews/workbench_catalog.dart';

void main() {
  for (final width in [320.0, 430.0]) {
    testWidgets('permission result, restore and login isolation $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final forbidden = <String>[];
      final messenger = tester.binding.defaultBinaryMessenger;
      for (final name in [
        'phone_agent/permissions',
        'plugins.it_nomads.com/flutter_secure_storage',
      ]) {
        final channel = MethodChannel(name);
        messenger.setMockMethodCallHandler(channel, (call) async {
          forbidden.add('$name:${call.method}');
          throw StateError('Real device port used by MOCK');
        });
        addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      }
      await tester.pumpWidget(
        MigrationWorkbench(
          scenes: [workbenchScenes.singleWhere((s) => s.id == 'app')],
        ),
      );
      Future<void> key(String value) async {
        await tester.pumpUntilUiSettled();
        final target = find.byKey(ValueKey(value));
        await tester.ensureVisible(target);
        await tester.tap(target);
        await tester.pumpUntilUiSettled();
        expect(tester.takeException(), isNull);
      }

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
        await key('send-text');
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpUntilUiSettled();
        expect(tester.takeException(), isNull);
      }

      await key('scene-app');
      final container = ProviderScope.containerOf(
        tester.element(find.byType(PhoneAgentApp)),
      );
      final ports = container.read(shellConversationPortsProvider);
      final permissions = container.read(shellPermissionPortsProvider);
      final auth = container.read(sessionStoreProvider) as AuthScenario;
      for (final scenario in [
        ('允许', 'OK', 2),
        ('拒绝', 'DENIED', 2),
        ('设置', 'SETTINGS_REQUIRED', 1),
      ]) {
        final before = ports.commands.length;
        final requestsBefore = permissions.requests.length;
        await key('tab-0');
        await key('skill-restaurant_booking');
        await send('演练权限${scenario.$1}');
        expect(ports.commands.length, before + 2);
        final action = ports.commands.last;
        expect(action.actionId, 'permission_result');
        expect(action.message, isNull);
        expect(action.actionPayload!['status'], scenario.$2);
        expect(permissions.requests.length, requestsBefore + scenario.$3);
        final text = 'MOCK · 权限结果：${scenario.$2}；可以继续文字。';
        expect(find.text(text), findsOneWidget);
        final history = await ports.restore(action.sessionId);
        expect(
          history.ledger!.events.where((e) => e.type == 'USER_TURN_ACCEPTED'),
          hasLength(1),
        );
        expect(
          history.ledger!.events.where((e) => e.type == 'TOOL_RESULT_RECORDED'),
          hasLength(1),
        );
        expect(history.pendingTool, isNull);
        await key('close-conversation');
        await key('tab-2');
        await key('conversation:${action.sessionId}');
        expect(find.text(text), findsOneWidget);
        expect(ports.commands.length, before + 2);
        expect(permissions.requests.length, requestsBefore + scenario.$3);
        await send('权限处理后继续文字');
        expect(ports.commands.last.actionId, isNull);
        expect(ports.commands.last.sessionId, action.sessionId);
        expect(find.text('已收到补充要求，当前为 MOCK，未拨号。'), findsOneWidget);
        await key('close-conversation');
      }
      expect(auth.sends, 0);
      expect(auth.submissions, isEmpty);
      final logout = container
          .read(sessionControllerProvider.notifier)
          .signOut();
      await tester.pumpUntilUiSettled();
      await logout;
      expect(
        container.read(shellPermissionPortsProvider),
        isNot(same(permissions)),
      );
      expect(container.read(shellPermissionPortsProvider).requests, isEmpty);
      expect(container.read(shellConversationPortsProvider).commands, isEmpty);
      expect(forbidden, isEmpty);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpUntilUiSettled();
    });
  }

  test(
    'permission result needs current pending request and is not replayed',
    () async {
      final ports = ShellConversationPorts(permissions: ShellPermissionPorts());
      AgentCommand command(
        String id, {
        String session = 's',
        bool result = false,
      }) => AgentCommand(
        sessionId: session,
        userId: 'synthetic',
        commandId: id,
        idempotencyKey: id,
        traceId: id,
        message: result ? null : '演练权限允许',
        actionId: result ? 'permission_result' : null,
        actionPayload: result
            ? {'permissionKey': 'contacts', 'status': 'OK'}
            : null,
      );
      await ports.start(command('request')).events.drain<void>();
      await expectLater(
        ports.start(command('wrong', session: 'other', result: true)).events,
        emitsError(isStateError),
      );
      await ports.start(command('result', result: true)).events.drain<void>();
      await expectLater(
        ports.start(command('duplicate', result: true)).events,
        emitsError(isStateError),
      );
      final history = await ports.restore('s');
      expect(
        history.ledger!.events.where((e) => e.type == 'TOOL_RESULT_RECORDED'),
        hasLength(1),
      );
      ports.close();
    },
  );
}
