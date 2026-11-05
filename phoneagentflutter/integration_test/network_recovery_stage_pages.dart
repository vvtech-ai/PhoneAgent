import '../test/support/pump_ui_transitions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/conversation_providers.dart';
import 'package:phone_agent/app/phone_agent_app.dart';
import 'package:phone_agent/app/task_error_status_providers.dart';
import 'package:phone_agent/features/conversation/domain/recovery/task_error_status_command.dart';
import '../tool/previews/shell_conversation_ports.dart';
import '../tool/previews/shell_network_error_ports.dart';

/// Same formal-page journey on Web preflight and devices. Business ports are
/// the selected MOCK scene's in-memory instances; no OS network switching.
Future<void> verifyNetworkRecoveryStage(
  WidgetTester tester, {
  required Future<void> Function(String) capture,
}) async {
  Future<void> tap(Finder finder) async {
    await tester.pumpUntilUiSettled();
    await Scrollable.ensureVisible(tester.element(finder), alignment: .35);
    await tester.pumpUntilUiSettled();
    await tester.tap(finder);
    await tester.pumpUntilUiSettled();
    expect(tester.takeException(), isNull);
  }

  Future<void> key(String value) => tap(find.byKey(ValueKey(value)));
  Future<void> input(String text, {VoidCallback? afterAccepted}) async {
    await tester.enterText(
      find.byKey(const ValueKey('conversation-input')),
      text,
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
    await tester.pumpUntilUiSettled();
    await tester.tap(find.byKey(const ValueKey('send-text')));
    afterAccepted?.call();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpUntilUiSettled();
  }

  final container = ProviderScope.containerOf(
    tester.element(find.byType(PhoneAgentApp)),
  );
  final server = container.read(shellNetworkErrorPortsProvider);
  expect(
    container.exists(taskErrorNetworkRecoveryProvider),
    isTrue,
    reason: '首页即建立账号监听',
  );
  final agent = container.read(agentGatewayProvider) as ShellConversationPorts;
  await key('skill-restaurant_booking');
  await key('toggle-text');
  // v66 precheck blocks starting offline; this scenario drops network after acceptance.
  await input('网络恢复验收', afterAccepted: () => server.setOnline(false));
  expect(agent.commands, hasLength(1));
  final id = agent.commands.single.sessionId;
  await capture('39-conversation-network-error');
  await key('close-conversation');
  await key('tab-2');
  expect(container.read(taskErrorStatusSyncProvider).hasPending, isTrue);
  expect(find.text('执行异常'), findsWidgets);
  await capture('40-task-pending-error');
  final attempts = server.sent.length;
  await tap(find.text('MOCK：恢复网络'));
  expect(server.sent.length, attempts + 1);
  expect(container.read(taskErrorStatusSyncProvider).hasPending, isFalse);
  expect(server.statuses[id], 'EXECUTION_ERROR');
  expect(agent.commands, hasLength(1));
  await key('conversation:$id');
  expect(agent.commands, hasLength(1), reason: '恢复历史不发送新需求');
  await key('toggle-text');
  await input('继续补充');
  expect(agent.commands, hasLength(2));
  expect(server.sent.last.reason, TaskErrorStatusReason.recovered);
  expect(server.statuses[id], 'RUNNING');
  expect(find.text('已收到补充要求，当前为 MOCK，未拨号。'), findsOneWidget);
  await capture('41-restored-business-reply');
  await key('close-conversation');
  final afterNormalExit = server.sent.length;
  await key('conversation:$id');
  await key('close-conversation');
  expect(server.sent.length, afterNormalExit, reason: '普通退出无状态中断');
  await capture('42-task-recovered');
}
