import '../test/support/pump_ui_transitions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/phone_agent_app.dart';
import 'package:phone_agent/features/calls/presentation/pages/call_session_page.dart';
import '../tool/previews/shell_call_preview.dart';
import '../tool/previews/shell_conversation_ports.dart';
import '../tool/previews/shell_log_report_preview.dart';

/// Continues the same App session after the dial/translation stage.
Future<void> verifyCallLogStage(
  WidgetTester tester, {
  required Future<void> Function(String name) capture,
}) async {
  final nativeCalls = <String>[];
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  for (final name in [
    'phone_agent/pcm_output',
    'com.vvtech.phone_agent/system_dialer',
  ]) {
    final channel = MethodChannel(name);
    messenger.setMockMethodCallHandler(channel, (call) async {
      nativeCalls.add('$name:${call.method}');
      throw StateError('Native media forbidden in stage');
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
  }
  Future<void> tap(Finder finder) async {
    await tester.pumpUntilUiSettled();
    if (finder.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        finder,
        150,
        scrollable: find.byType(Scrollable).last,
      );
    }
    await Scrollable.ensureVisible(tester.element(finder), alignment: .35);
    await tester.pumpUntilUiSettled();
    await tester.tap(finder);
    await tester.pumpUntilUiSettled();
    expect(tester.takeException(), isNull);
  }

  Future<void> key(String value) => tap(find.byKey(ValueKey(value)));
  Future<void> notice(String message) async {
    final target = find.textContaining(message);
    final deadline = tester.binding.clock.now().add(const Duration(seconds: 5));
    while (target.evaluate().isEmpty &&
        tester.binding.clock.now().isBefore(deadline)) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(target, findsOneWidget);
  }

  Future<void> input(String value) async {
    await tester.enterText(
      find.byKey(const ValueKey('conversation-input')),
      value,
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
    await tester.pumpUntilUiSettled();
    await key('send-text');
  }

  final container = ProviderScope.containerOf(
    tester.element(find.byType(PhoneAgentApp)),
  );
  final calls = container.read(shellCallPortsProvider);
  final conversations = container.read(shellConversationPortsProvider);
  final previousCommands = conversations.commands.length;
  await key('tab-0');
  await key('skill-restaurant_booking');
  await key('toggle-text');
  await input('演练单路通话');
  expect(find.byType(CallSessionPage), findsNothing);
  expect(conversations.commands.length, previousCommands + 1);
  await input('确认拨打');
  await tester.pump(const Duration(seconds: 2));
  await tester.pumpUntilUiSettled();
  expect(find.byType(CallSessionPage), findsOneWidget);
  final id = conversations.commands[previousCommands].sessionId;
  final flow = calls.flow(id)!;
  expect(flow.commands.where((c) => c.actionId == 'confirm_call').length, 1);
  await tester.pump(const Duration(seconds: 2));
  await tester.pumpUntilUiSettled();
  await key('call-开始监听');
  calls.monitor.pcm();
  await tester.pumpUntilUiSettled();
  expect(calls.monitor.receivedBytes, 3200);
  await capture('26-single-call-listening');
  await key('call-音源，听筒');
  await capture('27-single-call-source');
  await key('source-speaker');
  expect(calls.monitor.output!.selected, 'speaker');
  await key('call-停止监听');
  expect(calls.monitor.output!.enabled, isFalse);
  await key('call-开始监听');
  expect(calls.monitor.tickets, 1);
  await key('call-挂断');
  await tester.pump(const Duration(seconds: 2));
  await tester.pumpUntilUiSettled();
  expect(flow.hangups, 1);
  expect(find.byType(CallSessionPage), findsNothing);
  await key('close-conversation');
  await key('tab-2');
  await key('conversation:$id');
  expect(find.text('MOCK：单路任务已完成，已返回对话。'), findsOneWidget);
  await key('toggle-text');
  await input('再补充一个要求');
  expect(find.text('已收到补充要求，当前为 MOCK，未拨号。'), findsOneWidget);
  expect(find.byType(CallSessionPage), findsNothing);
  expect(flow.commands.length, 2);
  expect(calls.monitor.socket!.closed, isTrue);
  await capture('28-single-call-restored');
  await key('close-conversation');
  await key('tab-3');
  await key('settings-about');
  await key('about-logs');
  final logs = container.read(shellLogReportProvider);
  expect(find.textContaining('上传结果未确认'), findsOneWidget);
  expect(logs.uploads, 1);
  expect(logs.cleanups, 0);
  await capture('29-log-upload-failed');
  final bundle = logs.lastUpload;
  await key('about-logs');
  await notice('日志已上传，本地清理失败');
  expect(logs.lastUpload, same(bundle));
  await capture('30-log-cleanup-failed');
  await key('about-logs');
  await notice('日志上传成功');
  expect(logs.uploads, 2);
  expect(logs.cleanups, 2);
  await capture('31-log-upload-complete');
  await key('about-logs');
  expect(logs.lastUpload!.count, 0);
  expect(logs.uploads, 3);
  expect(container.read(shellLogReportProvider), same(logs));
  await capture('32-log-reopened');
  expect(nativeCalls, isEmpty);
  // About is a standalone route. Leave it before the next shell stage needs
  // tab controls; do not scroll inside About looking for an absent home tab.
  await tap(find.byTooltip('返回'));
  expect(find.byKey(const ValueKey('tab-0')), findsOneWidget);
}
