import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/conversation_providers.dart';
import '../test/support/pump_ui_transitions.dart';
import '../tool/previews/shell_conversation_ports.dart';

Future<void> verifyTaskQuestionsStage(
  WidgetTester tester,
  ShellConversationPorts ports,
  Future<void> Function(String) key,
  Future<void> Function(Finder) tap,
  Future<void> Function(String) screenshot,
) async {
  final before = ports.commands.length;
  await key('tab-0');
  await key('skill-restaurant_booking');
  await key('toggle-text');
  await tester.enterText(
    find.byKey(const ValueKey('conversation-input')),
    '演练需求问卷',
  );
  await key('send-text');
  final session = ports.commands.last.sessionId;
  expect(ports.commands, hasLength(before + 1));
  expect(find.textContaining('MOCK · 补充需求'), findsOneWidget);
  expect(find.byKey(const ValueKey('submit-question-answers')), findsNothing);
  await screenshot('06-natural-questions');
  await key('close-conversation');
  await key('tab-2');
  final container = ProviderScope.containerOf(
    tester.element(find.byKey(const ValueKey('tab-2'))),
  );
  for (
    var i = 0;
    i < 12 &&
        !container
            .read(taskControllerProvider)
            .catalog
            .records
            .any((r) => r.sessionId == session);
    i++
  ) {
    await tester.pump(const Duration(milliseconds: 250));
  }
  expect(
    container
        .read(taskControllerProvider)
        .catalog
        .records
        .any((r) => r.sessionId == session),
    isTrue,
    reason: '关闭原会话后列表应刷新展示新问卷任务',
  );
  await key('conversation:$session');
  expect(ports.commands, hasLength(before + 1), reason: '恢复不能回答问题');
  await key('toggle-text');
  final input = find.byKey(const ValueKey('conversation-input'));
  await tester.enterText(input, '电话号码2025550102，西餐，需要包间');
  await key('send-text');
  expect(ports.commands, hasLength(before + 2));
  expect(ports.commands.last.sessionId, session);
  expect(ports.commands.last.pendingToolCallId, isNotNull);
  expect(ports.commands.last.message, '电话号码2025550102，西餐，需要包间');
  expect(ports.commands.last.actionId, isNull);
  expect(ports.commands.last.actionPayload, isNull);
  await key('close-conversation');
  await key('conversation:$session');
  expect(find.byKey(const ValueKey('submit-question-answers')), findsNothing);
  final text = find.text('演练需求问卷');
  await tester.scrollUntilVisible(
    text,
    180,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.longPress(text);
  await tester.pumpUntilUiSettled();
  await tap(find.text('复制'));
  String? copied;
  for (var attempt = 0; attempt < 5; attempt++) {
    await tester.pump(const Duration(milliseconds: 200));
    copied = (await Clipboard.getData(Clipboard.kTextPlain))?.text;
    if (copied == '演练需求问卷') break;
  }
  expect(copied, '演练需求问卷');
  await screenshot('07-answered-question-history');
  await key('close-conversation');
  expect(ports.commands, hasLength(before + 2));
}
