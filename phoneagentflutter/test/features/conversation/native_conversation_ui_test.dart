import '../../support/pump_ui_transitions.dart';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/conversation_header.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/conversation_messages.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/conversation_composer.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/conversation_options_card.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      '$platform large text retains full brand and outer close action',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final semantics = tester.ensureSemantics();

        var closed = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: platform),
            home: Scaffold(
              body: MediaQuery(
                data: const MediaQueryData(textScaler: TextScaler.linear(2)),
                child: ConversationHeader(
                  onClose: () => closed++,
                  status: '文字输入',
                ),
              ),
            ),
          ),
        );
        expect(find.bySemanticsLabel('PhoneAgent'), findsOneWidget);
        final title = tester.widget<Text>(find.text('PhoneAgent'));
        expect(title.textScaler, TextScaler.noScaling);
        final subtitle = tester.widget<Text>(find.text('电话智能体 - 你的语音分身'));
        expect(subtitle.textScaler, isNull);
        final close = find.byKey(const ValueKey('close-conversation'));
        expect(tester.getSize(close), const Size(52, 52));
        final node = tester.getSemantics(find.bySemanticsLabel('关闭任务对话'));
        expect(node.hasFlag(SemanticsFlag.isButton), isTrue);
        expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
        // Click the outer hot area beyond the 40-point visible circle.
        await tester.tapAt(tester.getCenter(close) + const Offset(24, 0));
        await tester.pump();
        expect(closed, 1);
        semantics.dispose();
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets(
      '$platform side hot-area edges remain independent on narrow screens',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final semantics = tester.ensureSemantics();
        var added = 0, toggled = 0, mic = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: platform),
            home: Scaffold(
              body: MediaQuery(
                data: const MediaQueryData(textScaler: TextScaler.linear(2)),
                child: ConversationComposer(
                  voiceMode: true,
                  canSend: true,
                  modelName: 'QwenOmniPlus',
                  onToggle: () => toggled++,
                  onSend: (_) => false,
                  onNotice: (_) => mic++,
                  onModels: () {},
                  onAttachments: () => added++,
                ),
              ),
            ),
          ),
        );
        final add = tester.getRect(find.bySemanticsLabel('添加图片'));
        final toggle = tester.getRect(find.bySemanticsLabel('切换到文字输入'));
        final voice = tester.getRect(
          find.byKey(const ValueKey('conversation-voice-button')),
        );
        expect(add.right, lessThan(voice.left));
        expect(toggle.left, greaterThan(voice.right));
        await tester.tapAt(Offset(add.left + 1, add.center.dy));
        await tester.tapAt(Offset(toggle.right - 1, toggle.center.dy));
        await tester.pumpUntilUiSettled();
        expect([added, toggled, mic], [1, 1, 0]);
        final press = await tester.startGesture(toggle.center);
        await press.cancel();
        await tester.pumpUntilUiSettled();
        expect([added, toggled, mic], [1, 1, 0]);
        semantics.dispose();
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets(
      '$platform model hot area opens once and cancelled press does not',
      (tester) async {
        var opened = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: platform),
            home: Scaffold(
              body: ConversationComposer(
                voiceMode: false,
                canSend: true,
                modelName: 'QwenOmniPlus',
                onToggle: () {},
                onSend: (_) => false,
                onNotice: (_) {},
                onModels: () => opened++,
              ),
            ),
          ),
        );
        final input = find.byKey(const ValueKey('conversation-input'));
        await tester.enterText(input, '保留模型选择前的草稿');
        final model = find.byKey(const ValueKey('conversation-model'));
        final rect = tester.getRect(model);
        // The normal capsule is bottom aligned; its top hot area is transparent.
        await tester.tapAt(Offset(rect.center.dx, rect.top + 2));
        await tester.pump();
        expect(opened, 1);
        final press = await tester.startGesture(rect.center);
        await tester.pump();
        await press.cancel();
        await tester.pump();
        expect(opened, 1);
        expect(tester.widget<TextField>(input).controller!.text, '保留模型选择前的草稿');
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets('$platform icon controls have independent accessible actions', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      var closed = 0, added = 0, toggled = 0, models = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: platform),
          home: Scaffold(
            body: Column(
              children: [
                ConversationHeader(onClose: () => closed++, status: '按住按钮说话'),
                ConversationComposer(
                  voiceMode: true,
                  canSend: true,
                  modelName: 'QwenOmniPlus',
                  onToggle: () => toggled++,
                  onSend: (_) => true,
                  onNotice: (_) {},
                  onModels: () => models++,
                  onAttachments: () => added++,
                ),
              ],
            ),
          ),
        ),
      );
      for (final label in ['关闭任务对话', '添加图片', '切换到文字输入', '通话模型：QwenOmniPlus']) {
        final finder = find.bySemanticsLabel(label);
        expect(finder, findsOneWidget);
        final node = tester.getSemantics(finder);
        expect(node.hasFlag(SemanticsFlag.isButton), isTrue);
        expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
        tester.binding.performSemanticsAction(
          ui.SemanticsActionEvent(
            viewId: tester.view.viewId,
            nodeId: node.id,
            type: SemanticsAction.tap,
          ),
        );
      }
      expect([closed, added, toggled, models], [1, 1, 1, 1]);
      final voice = tester.getSemantics(find.bySemanticsLabel('按住说话'));
      expect(voice.hasFlag(SemanticsFlag.isButton), isTrue);
      expect(voice.getSemanticsData().hasAction(SemanticsAction.tap), isFalse);
      expect(
        voice.getSemanticsData().hasAction(SemanticsAction.longPress),
        isFalse,
      );
      var sent = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConversationComposer(
              voiceMode: false,
              canSend: true,
              modelName: 'QwenOmniPlus',
              onToggle: () => toggled++,
              onSend: (_) {
                sent++;
                return true;
              },
              onNotice: (_) {},
              onModels: () {},
              onAttachments: () => added++,
            ),
          ),
        ),
      );
      for (final label in ['添加图片', '切换到语音输入', '发送文字']) {
        expect(find.bySemanticsLabel(label), findsOneWidget);
      }
      final disabled = tester.getSemantics(find.bySemanticsLabel('发送文字'));
      expect(disabled.hasFlag(SemanticsFlag.hasEnabledState), isTrue);
      expect(disabled.hasFlag(SemanticsFlag.isEnabled), isFalse);
      expect(
        disabled.getSemanticsData().hasAction(SemanticsAction.tap),
        isFalse,
      );
      await tester.enterText(
        find.byKey(const ValueKey('conversation-input')),
        '合成任务',
      );
      await tester.pumpUntilUiSettled();
      final send = tester.getSemantics(find.bySemanticsLabel('发送文字'));
      expect(send.hasFlag(SemanticsFlag.isEnabled), isTrue);
      tester.binding.performSemanticsAction(
        ui.SemanticsActionEvent(
          viewId: tester.view.viewId,
          nodeId: send.id,
          type: SemanticsAction.tap,
        ),
      );
      await tester.pumpUntilUiSettled();
      expect(sent, 1);
      handle.dispose();
      expect(tester.takeException(), isNull);
    });
    testWidgets(
      '$platform shared dock retains draft and sends once with large text',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        var voice = false, attachments = 0;
        final sent = <String>[];
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: platform),
            home: Scaffold(
              body: MediaQuery(
                data: const MediaQueryData(
                  size: Size(320, 568),
                  textScaler: TextScaler.linear(2),
                ),
                child: StatefulBuilder(
                  builder: (context, change) => ConversationComposer(
                    voiceMode: voice,
                    canSend: true,
                    modelName: '较长的模型名称，保留单行显示',
                    onToggle: () => change(() => voice = !voice),
                    onSend: (text) {
                      sent.add(text);
                      return true;
                    },
                    onNotice: (_) {},
                    onModels: () {},
                    onAttachments: () => attachments++,
                  ),
                ),
              ),
            ),
          ),
        );
        final input = find.byKey(const ValueKey('conversation-input'));
        await tester.enterText(input, '保留草稿');
        await tester.tap(find.byKey(const ValueKey('toggle-voice')));
        await tester.pumpUntilUiSettled();
        await tester.tap(find.byKey(const ValueKey('toggle-text')));
        await tester.pumpUntilUiSettled();
        expect(tester.widget<TextField>(input).controller!.text, '保留草稿');
        await tester.tap(find.bySemanticsLabel('添加图片'));
        expect(attachments, 1);
        final send = find.byKey(const ValueKey('send-text'));
        await tester.tapAt(tester.getTopLeft(send) + const Offset(2, 24));
        await tester.pumpUntilUiSettled();
        expect(sent, ['保留草稿']);
        expect(tester.widget<TextField>(input).controller!.text, isEmpty);
        await tester.tap(send);
        expect(sent.length, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'candidate rejection can retry, accepted choice locks, refresh re-enables',
    (tester) async {
      var accepted = false, choices = 0;
      const message = ConversationMessage(
        id: 'candidate',
        role: MessageRole.assistant,
        text: '请选择',
        options: [ConversationOption('甲', '说明'), ConversationOption('乙', '')],
      );
      Future<void> render(bool enabled) => tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConversationOptionsCard(
              message: message,
              enabled: enabled,
              onSelect: (_) {
                choices++;
                return accepted;
              },
            ),
          ),
        ),
      );
      final first = find.byKey(const ValueKey('option:candidate:0'));
      await render(true);
      await tester.tap(first);
      await tester.pump();
      expect(choices, 1);
      accepted = true;
      await tester.tap(first);
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('option:candidate:1')));
      expect(choices, 2);
      await render(false);
      await render(true);
      await tester.tap(first);
      expect(choices, 3);
      expect(tester.takeException(), isNull);
    },
  );
}
