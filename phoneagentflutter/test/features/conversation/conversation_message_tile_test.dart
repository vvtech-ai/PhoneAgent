import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/conversation_messages.dart';
import 'package:phone_agent/features/conversation/domain/conversation_questions.dart';
import 'package:phone_agent/features/conversation/domain/conversation_tool_card.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/conversation_message_tile.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/native_conversation_text_bubble.dart';

void main() {
  Future<void> render(
    WidgetTester tester,
    ConversationMessage message, {
    bool enabled = false,
    ValueChanged<int>? choose,
  }) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 280,
          child: ConversationMessageTile(
            message: message,
            optionsEnabled: enabled,
            onChoose: choose ?? (_) {},
          ),
        ),
      ),
    ),
  );
  testWidgets(
    'long user/assistant messages respect separate source width and shape',
    (tester) async {
      for (final role in [MessageRole.user, MessageRole.assistant]) {
        await render(
          tester,
          ConversationMessage(id: 'a', role: role, text: '长消息内容' * 20),
        );
        final container = tester.widget<Container>(
          find.byKey(const ValueKey('message:a')),
        );
        expect(
          container.constraints!.maxWidth,
          role == MessageRole.user ? 220 : 260,
        );
        final decoration = container.decoration! as BoxDecoration;
        expect(decoration.gradient != null, role == MessageRole.user);
        final text = tester.widget<SelectableText>(find.byType(SelectableText));
        expect(text.style!.fontSize, 14);
        expect(text.style!.height, 22 / 14);
        expect(text.style!.letterSpacing, 0);
        expect(text.style!.fontWeight, FontWeight.w400);
        expect(tester.takeException(), isNull);
      }
    },
  );
  testWidgets('generic ask-user summary keeps concrete prompts visible', (
    tester,
  ) async {
    await render(
      tester,
      ConversationMessage(
        id: 'ask-user-prompts',
        role: MessageRole.assistant,
        text: '需要你补充信息',
        questions: ConversationQuestions('请补充会议安排', [
          ConversationQuestion(id: 'date', prompt: '会议日期'),
          ConversationQuestion(id: 'place', prompt: '会议地点'),
        ]),
      ),
    );

    expect(find.textContaining('请补充会议安排'), findsOneWidget);
    expect(find.textContaining('会议日期'), findsOneWidget);
    expect(find.textContaining('会议地点'), findsOneWidget);
    expect(find.text('需要你补充信息'), findsNothing);
  });
  testWidgets('short ordinary bubbles share minimum width and respect bounds', (
    tester,
  ) async {
    for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
      for (final scale in [1.0, 2.0]) {
        for (final role in [MessageRole.user, MessageRole.assistant]) {
          for (final width in [280.0, 40.0]) {
            await tester.pumpWidget(
              MaterialApp(
                theme: ThemeData(platform: platform),
                home: Scaffold(
                  body: MediaQuery(
                    data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                    child: SizedBox(
                      width: width,
                      child: ConversationMessageTile(
                        message: ConversationMessage(
                          id: 'short',
                          role: role,
                          text: '.',
                        ),
                        optionsEnabled: false,
                        onChoose: (_) {},
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            final bubble = find.byKey(const ValueKey('message:short'));
            final decoration = find
                .descendant(of: bubble, matching: find.byType(DecoratedBox))
                .first;
            final rect = tester.getRect(decoration);
            final maximum = width.clamp(
              0.0,
              role == MessageRole.user ? 220.0 : 260.0,
            );
            final painter = TextPainter(
              text: const TextSpan(
                text: '.',
                style: TextStyle(
                  fontSize: 14,
                  height: 22 / 14,
                  letterSpacing: 0,
                  fontWeight: FontWeight.w400,
                ),
              ),
              textDirection: TextDirection.ltr,
              textScaler: TextScaler.linear(scale),
            )..layout();
            final natural = painter.width.ceilToDouble() + 28;
            painter.dispose();
            expect(
              rect.width,
              greaterThanOrEqualTo(
                natural.clamp(maximum.clamp(0.0, 44.0), maximum),
              ),
            );
            expect(
              rect.width,
              lessThanOrEqualTo(
                (natural + 4).clamp(maximum.clamp(0.0, 44.0), maximum),
              ),
            );

            expect(rect.width, lessThanOrEqualTo(maximum));
            final style =
                tester.widget<Container>(bubble).decoration! as BoxDecoration;
            expect(style.gradient != null, role == MessageRole.user);
            expect(tester.takeException(), isNull);
          }
        }
      }
    }
  });
  testWidgets(
    'tool card exposes display fields without execution actions or fabricated success',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final card = ConversationToolCard.fromPayload({
        'toolName': 'search',
        'methodLabel': 'search(restaurant)',
        'body': 'keyword: "晚餐"',
        'result': '未找到匹配结果',
        'status': 'FAILED',
      });
      await render(
        tester,
        ConversationMessage(
          id: 'tool',
          role: MessageRole.assistant,
          text: card.result,
          toolCard: card,
        ),
      );
      expect(find.text('search(restaurant)'), findsOneWidget);
      expect(find.bySemanticsLabel('keyword: "晚餐"'), findsOneWidget);
      expect(find.bySemanticsLabel('未找到匹配结果'), findsOneWidget);
      expect(find.byType(TextButton), findsNothing);
      expect(find.textContaining('已完成'), findsNothing);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );
  testWidgets('only enabled candidate rows dispatch their own ordinal', (
    tester,
  ) async {
    const message = ConversationMessage(
      id: 'options',
      role: MessageRole.assistant,
      text: '请选择',
      options: [ConversationOption('甲', '说明甲'), ConversationOption('乙', '')],
    );
    final choices = <int>[];
    await render(tester, message, enabled: true, choose: choices.add);
    await tester.tap(find.byKey(const ValueKey('option:options:1')));
    expect(choices, [1]);
    await render(tester, message, choose: choices.add);
    await tester.tap(find.byKey(const ValueKey('option:options:0')));
    expect(choices, [1]);
  });

  testWidgets('locked apology model card stays visible and cannot be tapped', (
    tester,
  ) async {
    const message = ConversationMessage(
      id: 'local:apology:model-prompt:2',
      role: MessageRole.assistant,
      text: '请选择已有克隆音色的模型。',
      options: [ConversationOption('豆包', ''), ConversationOption('不使用', '')],
      optionsLocked: true,
      selectedOptionIndex: 0,
    );
    final choices = <int>[];
    await render(tester, message, enabled: true, choose: choices.add);
    expect(find.text('请选择已有克隆音色的模型。'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('option:local:apology:model-prompt:2:1')),
    );
    expect(choices, isEmpty);
  });
  testWidgets('apology question stays above a selected disabled card', (
    tester,
  ) async {
    const message = ConversationMessage(
      id: 'local:apology:1:assistant',
      role: MessageRole.assistant,
      text: '确认使用吗？',
      options: [ConversationOption('确认使用', ''), ConversationOption('不使用', '')],
      optionsLocked: true,
      selectedOptionIndex: 0,
    );
    await render(tester, message);
    final question = find.widgetWithText(
      NativeConversationTextBubble,
      '确认使用吗？',
    );
    final card = find.byKey(
      const ValueKey('message:local:apology:1:assistant'),
    );
    expect(question, findsOneWidget);
    expect(
      find.descendant(of: card, matching: find.text('确认使用吗？')),
      findsNothing,
    );
    expect(
      tester.getBottomLeft(question).dy,
      lessThanOrEqualTo(tester.getTopLeft(card).dy),
    );
    expect(
      tester
          .widget<InkWell>(
            find.byKey(const ValueKey('option:local:apology:1:assistant:0')),
          )
          .onTap,
      isNull,
    );
    final selectedRow = find.byKey(
      const ValueKey('option:local:apology:1:assistant:0'),
    );
    expect(
      tester
          .widget<Material>(
            find
                .ancestor(of: selectedRow, matching: find.byType(Material))
                .first,
          )
          .color,
      const Color(0xFFEAF3FF),
    );
  });

  testWidgets('ordinary locked option keeps its existing neutral style', (
    tester,
  ) async {
    const message = ConversationMessage(
      id: 'ordinary-locked',
      role: MessageRole.assistant,
      text: '请选择',
      options: [ConversationOption('甲', '')],
      optionsLocked: true,
      selectedOptionIndex: 0,
    );
    await render(tester, message);
    final selectedRow = find.byKey(const ValueKey('option:ordinary-locked:0'));
    expect(
      tester
          .widget<Material>(
            find
                .ancestor(of: selectedRow, matching: find.byType(Material))
                .first,
          )
          .color,
      const Color(0xFFE5E7EB),
    );
  });

  testWidgets('selected card remains a disabled historical snapshot', (
    tester,
  ) async {
    const message = ConversationMessage(
      id: 'history-options',
      role: MessageRole.assistant,
      text: '请选择',
      options: [ConversationOption('甲', ''), ConversationOption('乙', '')],
    );
    var enabled = true;
    Widget page() => MaterialApp(
      home: Scaffold(
        body: ConversationMessageTile(
          message: message,
          optionsEnabled: enabled,
          onChoose: (_) => enabled = false,
        ),
      ),
    );
    await tester.pumpWidget(page());
    await tester.tap(find.byKey(const ValueKey('option:history-options:0')));
    await tester.pump();
    enabled = false;
    await tester.pumpWidget(page());
    final option = tester.widget<InkWell>(
      find.byKey(const ValueKey('option:history-options:0')),
    );
    expect(option.onTap, isNull);
  });
}
