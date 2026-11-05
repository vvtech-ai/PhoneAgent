import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/conversation_messages.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/conversation_message_tile.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final width in [240.0, 320.0, 390.0, 430.0]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('$platform width $width scale $scale native bubble edges', (
          tester,
        ) async {
          tester.view.physicalSize = Size(width, 1800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final long = List.filled(12, '这是一段验证旧版对话宽度的合成消息。').join();
          final messages = [
            ConversationMessage(
              id: 'ai',
              role: MessageRole.assistant,
              text: long,
            ),
            ConversationMessage(id: 'user', role: MessageRole.user, text: long),
            const ConversationMessage(
              id: 'short',
              role: MessageRole.assistant,
              text: '好。',
            ),
            const ConversationMessage(
              id: 'local:apology:models',
              role: MessageRole.assistant,
              text: '请选择',
              options: [ConversationOption('合成模型', '')],
            ),
            const ConversationMessage(
              id: 'normal-options',
              role: MessageRole.assistant,
              text: '请选择',
              options: [ConversationOption('合成候选', '')],
            ),
          ];
          int? selected;
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(platform: platform),
              home: Scaffold(
                body: MediaQuery(
                  data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final message in messages)
                            KeyedSubtree(
                              key: ValueKey('row:${message.id}'),
                              child: ConversationMessageTile(
                                message: message,
                                optionsEnabled: true,
                                onChoose: (index) => selected = index,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          Rect surface(String id, Type type) => tester.getRect(
            find
                .descendant(
                  of: find.byKey(ValueKey('row:$id')),
                  matching: find.byType(type),
                )
                .first,
          );
          final ai = surface('ai', DecoratedBox);
          final user = surface('user', DecoratedBox);
          final short = surface('short', DecoratedBox);
          final apology = surface('local:apology:models', DecoratedBox);
          final options = surface('local:apology:models', Material);
          final normal = surface('normal-options', Material);
          final available = width - 36;
          // Like Compose wrapContent, the longest rendered line may leave
          // less than one glyph of space below the maximum bubble width.
          expect(
            ai.width,
            inInclusiveRange(
              available.clamp(0, 260) - 14 * scale,
              available.clamp(0, 260),
            ),
          );
          expect(
            user.width,
            inInclusiveRange(
              available.clamp(0, 220) - 14 * scale,
              available.clamp(0, 220),
            ),
          );
          expect(ai.left, closeTo(18, .01));
          expect(user.right, closeTo(width - 18, .01));
          expect(short.width, lessThan(ai.width));
          expect(short.left, ai.left);
          expect(apology.left, ai.left);
          expect(apology.width, closeTo(available.clamp(0, 260), .01));
          expect(options.left, apology.left);
          expect(options.right, closeTo(apology.right, .01));
          expect(normal.width, closeTo(available.clamp(0, 284), .01));
          final option = find.byKey(
            const ValueKey('option:local:apology:models:0'),
          );
          await tester.ensureVisible(option);
          await tester.tap(option);
          await tester.pump();
          expect(selected, 0);
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}
