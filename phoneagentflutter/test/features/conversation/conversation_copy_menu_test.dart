import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/conversation_messages.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/conversation_message_tile.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('$platform copies complete ordinary text, excludes streaming', (
      tester,
    ) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      const text = '完整原文\n第二行 📞';
      Future<void> render({
        bool streaming = false,
        MessageRole role = MessageRole.assistant,
      }) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: platform),
            home: Scaffold(
              body: ConversationMessageTile(
                message: ConversationMessage(
                  id: 'copy',
                  role: role,
                  text: text,
                ),
                optionsEnabled: false,
                onChoose: (_) {},
                streaming: streaming,
              ),
            ),
          ),
        );
        await tester.pump();
      }

      await render();
      await tester.longPress(find.byKey(const ValueKey('message:copy')));
      await tester.pumpAndSettle();
      expect(find.text('复制'), findsOneWidget);
      await tester.tap(find.text('复制'));
      await tester.pumpAndSettle();
      expect(copied, text);
      await render(streaming: true);
      await tester.longPress(find.byKey(const ValueKey('message:copy')));
      await tester.pumpAndSettle();
      expect(find.text('复制'), findsNothing);
      await render(role: MessageRole.notice);
      await tester.longPress(find.byKey(const ValueKey('message:copy')));
      await tester.pumpAndSettle();
      expect(find.text('复制'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
