import '../test/support/pump_ui_transitions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/conversation_providers.dart';
import 'package:phone_agent/app/phone_agent_app.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/native_conversation_precheck_card.dart';
import '../tool/previews/shell_conversation_fakes.dart';

/// Real routes and controls; only business IO is provided by the MOCK host.
/// Widget preflight injects insets explicitly; device runs use actual OS metrics.
Future<void> verifyKeyboardStage(
  WidgetTester tester, {
  required Future<void> Function(String) capture,
  Future<void> Function(bool shown)? simulateKeyboard,
}) async {
  Future<void> key(String value) async {
    await tester.pumpUntilUiSettled();
    final target = find.byKey(ValueKey(value));
    await Scrollable.ensureVisible(tester.element(target), alignment: .35);
    await tester.pumpUntilUiSettled();
    await tester.tap(target);
    await tester.pumpUntilUiSettled();
    expect(tester.takeException(), isNull);
  }

  double inset() =>
      tester.view.viewInsets.bottom / tester.view.devicePixelRatio;
  Future<void> waitKeyboard(bool shown) async {
    await simulateKeyboard?.call(shown);
    for (var i = 0; i < 50; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (shown ? inset() > 100 : inset() == 0) break;
    }
    expect(
      inset(),
      shown ? greaterThan(100) : 0,
      reason:
          'A real device must report keyboard insets; no silent mock fallback',
    );
    await tester.pumpUntilUiSettled();
    expect(tester.takeException(), isNull);
  }

  void checkComposer() {
    final size = tester.view.physicalSize / tester.view.devicePixelRatio;
    for (final name in ['conversation-input', 'send-text']) {
      final finder = find.byKey(ValueKey(name));
      final rect = tester.getRect(finder);
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(size.width));
      expect(rect.top, greaterThanOrEqualTo(0));
      expect(rect.bottom, lessThanOrEqualTo(size.height - inset() + 1));
      expect(finder.hitTestable(), findsOneWidget);
    }
  }

  final container = ProviderScope.containerOf(
    tester.element(find.byType(PhoneAgentApp)),
  );
  final agent = container.read(agentGatewayProvider) as OfflineAgent;
  await key('skill-restaurant_booking');
  await key('toggle-text');
  await tester.tap(find.byKey(const ValueKey('conversation-input')));
  await waitKeyboard(true);
  checkComposer();
  await capture('43-conversation-system-keyboard');
  await _verifyMultilineFocus(tester, checkComposer, inset);
  await capture('47-multiline-keyboard-focus');
  await tester.enterText(
    find.byKey(const ValueKey('conversation-input')),
    '键盘布局测试',
  );
  await tester.pumpUntilUiSettled();
  checkComposer();
  await capture('44-keyboard-send-reachable');
  // Tap the actual send button while the keyboard remains visible.
  await key('send-text');
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pumpUntilUiSettled();
  expect(agent.commands, hasLength(1));
  expect(agent.commands.single.message, '键盘布局测试');
  final id = agent.commands.single.sessionId;
  FocusManager.instance.primaryFocus?.unfocus();
  await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
  await waitKeyboard(false);
  expect(find.text('键盘布局测试'), findsOneWidget);
  await capture('45-keyboard-dismissed-reply');
  await key('close-conversation');
  await key('tab-2');
  await key('conversation:$id');
  for (
    var i = 0;
    i < 40 && find.byType(NativeConversationPrecheckCard).evaluate().isNotEmpty;
    i++
  ) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(
    find.byType(NativeConversationPrecheckCard),
    findsNothing,
    reason: 'Healthy restored task completes its finite entry checks',
  );
  if (find.text('键盘布局测试').evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      find.text('键盘布局测试'),
      120,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('conversation-timeline')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pumpUntilUiSettled();
  }
  expect(find.text('键盘布局测试'), findsOneWidget);
  expect(agent.commands, hasLength(1), reason: 'Restore does not resend');
  await capture('46-keyboard-task-restored');
  await key('close-conversation');
}

Future<void> _verifyMultilineFocus(
  WidgetTester tester,
  VoidCallback checkComposer,
  double Function() inset,
) async {
  final input = find.byKey(const ValueKey('conversation-input'));
  final editable = find.descendant(
    of: input,
    matching: find.byType(EditableText),
  );
  final editor = tester.state<EditableTextState>(editable);
  for (final text in ['第一行\n', '第一行\n第二行\n第三行', '自动折行文字' * 30, '恢复一行']) {
    // Do not call showKeyboard/refocus between updates: that hides the defect.
    tester.testTextInput.enterText(text);
    await tester.pumpUntilUiSettled();
    expect(tester.state<EditableTextState>(editable), same(editor));
    expect(tester.widget<EditableText>(editable).focusNode.hasFocus, isTrue);
    expect(inset(), greaterThan(100), reason: 'Keyboard must remain visible');
    checkComposer();
  }
}
