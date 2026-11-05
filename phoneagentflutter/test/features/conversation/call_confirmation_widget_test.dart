import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/call_confirmation.dart';
import 'package:phone_agent/features/conversation/domain/conversation_messages.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/conversation_message_tile.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/call_confirmation_card.dart';

void main() {
  testWidgets(
    'confirmation is readable on narrow screen, no execution buttons',
    (tester) async {
      final card = CallConfirmation.fromPayload({
        'targetName': '合成餐厅',
        'phoneNumber': '000',
        'primaryGoal': '仅合成测试',
        'summaryLines': ['人数：三人'],
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
              child: SizedBox(
                width: 276,
                child: ConversationMessageTile(
                  message: ConversationMessage(
                    id: 'c',
                    role: MessageRole.assistant,
                    text: '',
                    confirmation: card,
                  ),
                  optionsEnabled: false,
                  onChoose: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.text('任务确认'), findsOneWidget);
      expect(find.text('可执行'), findsNothing);
      expect(find.text('合成餐厅'), findsOneWidget);
      expect(find.text('000'), findsOneWidget);
      expect(find.text('三人'), findsOneWidget);
      expect(find.text('请确认以上任务内容，是否现在拨打？'), findsNothing);
      expect(find.byType(TextButton), findsNothing);
      expect(find.byType(ElevatedButton), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'confirmation uses native width and does not truncate single-call facts',
    (tester) async {
      final detail = List.filled(15, '用户已明确提出的附加要求').join('，');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CallConfirmationCard(
              confirmation: CallConfirmation(
                targetName: '测试餐厅',
                phoneNumber: '000',
                primaryGoal: detail,
                summaryLines: [],
              ),
            ),
          ),
        ),
      );
      final card = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(CallConfirmationCard),
              matching: find.byType(Container),
            )
            .first,
      );
      expect(card.constraints!.maxWidth, 280);
      expect((card.decoration! as BoxDecoration).gradient!.colors, [
        const Color(0xFFEDFAF0),
        const Color(0xFFD6F5DC),
      ]);
      expect(tester.widget<Text>(find.text(detail)).maxLines, isNull);
      expect(tester.takeException(), isNull);
    },
  );
}
