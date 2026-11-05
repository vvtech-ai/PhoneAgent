import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/conversation_messages.dart';
import 'package:phone_agent/features/conversation/domain/conversation_tool_card.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/conversation_message_tile.dart';

void main() {
  testWidgets(
    'permission refusal and waiting never look like successful grants',
    (tester) async {
      for (final status in ['DENIED', 'SETTINGS_REQUIRED', 'waiting']) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ConversationMessageTile(
                message: ConversationMessage(
                  id: 'permission',
                  role: MessageRole.assistant,
                  text: '',
                  toolCard: ConversationToolCard.fromPayload({
                    'toolName': 'requestPermission',
                    'status': status,
                    'result': status == 'waiting' ? '等待用户授权' : '用户未授权',
                  }),
                ),
                optionsEnabled: false,
                onChoose: (_) {},
              ),
            ),
          ),
        );
        expect(
          find.textContaining('✓'),
          findsNothing,
          reason: '等待或拒绝只能展示真实状态，不能标为成功',
        );
        expect(
          find.textContaining(status == 'waiting' ? '等待用户授权' : '用户未授权'),
          findsOneWidget,
        );
      }
    },
  );
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('$platform tool icons and server result at large font', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      for (final item in {
        'search': 'S',
        'askUser': 'A',
        'showOptions': 'O',
        'makeCall': 'C',
        'stageReport': 'R',
        'unknown': '查',
      }.entries) {
        final card = ConversationToolCard.fromPayload({
          'toolName': item.key,
          'methodLabel': '查询资料',
          'body': 'keyword: "合成餐厅"\n备注: "这是一段用于短屏大字体排版验证的较长条件"',
          'result': '服务返回三项',
          'status': 'COMPLETED',
        });
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: platform),
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(320, 640),
                textScaler: TextScaler.linear(2),
              ),
              child: Scaffold(
                body: SingleChildScrollView(
                  child: ConversationMessageTile(
                    message: ConversationMessage(
                      id: 'tool',
                      role: MessageRole.assistant,
                      text: '',
                      toolCard: card,
                    ),
                    optionsEnabled: false,
                    onChoose: (_) {},
                  ),
                ),
              ),
            ),
          ),
        );
        expect(find.text(item.value), findsOneWidget);
        expect(find.text('✓ 服务返回三项'), findsOneWidget);
        expect(find.text(card.body), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
      for (final status in ['', 'RUNNING', 'COMPLETED']) {
        final card = ConversationToolCard.fromPayload({
          'toolName': 'search',
          'status': status,
        });
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ConversationMessageTile(
                message: ConversationMessage(
                  id: 'empty',
                  role: MessageRole.assistant,
                  text: '',
                  toolCard: card,
                ),
                optionsEnabled: false,
                onChoose: (_) {},
              ),
            ),
          ),
        );
        expect(
          find.textContaining('✓'),
          findsNothing,
          reason: '状态或流结束不能生成服务结果',
        );
        expect(tester.takeException(), isNull);
      }
    });
  }
}
