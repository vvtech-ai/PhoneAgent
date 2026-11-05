import '../../support/pump_ui_transitions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/mobile_preview.dart';
import 'package:phone_agent/features/conversation/domain/conversation_messages.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_state.dart';
import 'package:phone_agent/features/conversation/presentation/pages/conversation_page.dart';

void main() {
  for (final width in [320.0, 390.0, 430.0]) {
    for (final phase in [
      ConversationPhase.ready,
      ConversationPhase.recoveryRequired,
      ConversationPhase.restoreFailed,
    ]) {
      testWidgets('empty conversation $phase with keyboard at $width', (
        tester,
      ) async {
        var retries = 0;
        await _mount(
          tester,
          width: width,
          state: ConversationState(
            entry: const ConversationEntry(sessionId: 'synthetic'),
            voiceMode: false,
            phase: phase,
            notice: phase == ConversationPhase.ready
                ? ''
                : '连接中断或响应异常，请同步历史后继续；不会自动重复提交任务。',
          ),
          onRetry: () => retries++,
        );
        expect(tester.takeException(), isNull);
        final input = find.byKey(const ValueKey('conversation-input'));
        expect(tester.getRect(input).bottom, lessThanOrEqualTo(268));
        expect(
          find.byKey(const ValueKey('close-conversation')).hitTestable(),
          findsOneWidget,
        );
        if (phase != ConversationPhase.ready) {
          expect(find.text('同步历史并重试'), findsNothing);
          final retry = find.text(
            phase == ConversationPhase.restoreFailed
                ? '同步失败，点击重试'
                : '连接中断，点击重试',
          );
          await tester.scrollUntilVisible(
            retry,
            40,
            scrollable: find.descendant(
              of: find.byKey(const ValueKey('conversation-timeline')),
              matching: find.byType(Scrollable),
            ),
          );
          await Scrollable.ensureVisible(tester.element(retry), alignment: .5);
          await tester.pumpUntilUiSettled();
          await tester.tap(retry);
          expect(retries, 1);
        }
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('long options scroll into view without hiding composer', (
    tester,
  ) async {
    int? chosen;
    await _mount(
      tester,
      width: 320,
      state: ConversationState(
        entry: const ConversationEntry(sessionId: 'synthetic'),
        voiceMode: false,
        activeOptionsId: 'options',
        messages: [
          ConversationMessage(
            id: 'options',
            role: MessageRole.assistant,
            text: '请选择一个候选对象',
            options: List.generate(
              8,
              (i) => ConversationOption('合成候选 $i', '较长的条件说明，仅用于布局验证。'),
            ),
          ),
        ],
      ),
      onChoose: (_, index) {
        chosen = index;
        return true;
      },
    );
    expect(tester.takeException(), isNull);
    final candidate = find.byKey(const ValueKey('option:options:0'));
    await Scrollable.ensureVisible(tester.element(candidate), alignment: .5);
    await tester.pumpUntilUiSettled();
    await tester.tap(candidate);
    expect(chosen, 0);
    expect(
      tester.getRect(find.byKey(const ValueKey('conversation-input'))).bottom,
      lessThanOrEqualTo(268),
    );
    expect(tester.takeException(), isNull);
  });
}

Future<void> _mount(
  WidgetTester tester, {
  required double width,
  required ConversationState state,
  VoidCallback? onRetry,
  bool Function(String, int)? onChoose,
}) async {
  tester.view.physicalSize = Size(width, 568);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          viewInsets: const EdgeInsets.only(bottom: 300),
          textScaler: const TextScaler.linear(1.3),
        ),
        child: MobilePreview(child: child!),
      ),
      home: Scaffold(
        body: ConversationPage(
          state: state,
          modelName: '用于测试长名称溢出的模型名称',
          onClose: () {},
          onToggle: () {},
          onSend: (_) => true,
          onChoose: onChoose ?? (_, __) => true,
          onRetry: onRetry ?? () {},
          onNotice: (_) {},
          onModels: () {},
        ),
      ),
    ),
  );
  await tester.pumpUntilUiSettled();
}
