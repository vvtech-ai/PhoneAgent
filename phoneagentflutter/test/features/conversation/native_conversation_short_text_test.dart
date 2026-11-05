import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/native_conversation_text_bubble.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final scale in [1.0, 2.0]) {
      for (final text in ['第 1 个', '已收到你的选择。']) {
        for (final user in [false, true]) {
          testWidgets(
            '$platform $user short reply "$text" fits native bounds at $scale',
            (tester) async {
              await tester.pumpWidget(
                MaterialApp(
                  theme: ThemeData(platform: platform),
                  home: Scaffold(
                    body: MediaQuery(
                      data: MediaQueryData(
                        textScaler: TextScaler.linear(scale),
                      ),
                      child: SizedBox(
                        width: 360,
                        child: NativeConversationTextBubble(
                          text: text,
                          user: user,
                          bubbleKey: const ValueKey('short-bubble'),
                        ),
                      ),
                    ),
                  ),
                ),
              );
              await tester.pumpAndSettle();
              final paragraph = tester.getRect(find.byType(SelectableText));
              final bubble = tester.getRect(
                find
                    .descendant(
                      of: find.byKey(const ValueKey('short-bubble')),
                      matching: find.byType(DecoratedBox),
                    )
                    .first,
              );
              // At doubled font size this user reply wraps in the legacy
              // 220dp bubble; the shorter phrase and AI reply still fit.
              final lines = user && scale == 2 && text == '已收到你的选择。' ? 2 : 1;
              expect(paragraph.height, closeTo(22 * scale * lines, .5));
              expect(bubble.width, lessThanOrEqualTo(user ? 220 : 260));
              expect(
                tester.widget<SelectableText>(find.byType(SelectableText)).data,
                text,
              );
              expect(tester.takeException(), isNull);
            },
          );
        }
      }
    }
  }
}
