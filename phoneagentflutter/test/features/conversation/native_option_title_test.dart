import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/conversation_messages.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/conversation_options_card.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('$platform candidate title edges at $scale', (tester) async {
        var selected = -1;
        Future<void> show(String title) => tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: platform),
            home: Scaffold(
              body: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                child: Column(
                  children: [
                    ConversationOptionsCard(
                      message: ConversationMessage(
                        id: 'title-fixture',
                        role: MessageRole.assistant,
                        text: title,
                        options: const [ConversationOption('合成候选', '')],
                      ),
                      enabled: true,
                      onSelect: (index) {
                        selected = index;
                        return true;
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        const short = '合成标题';
        await show(short);
        expect(tester.getSize(find.text(short)).height, lessThan(24 * scale));
        final long = List.filled(10, '合成长标题').join();
        await show(long);
        final title = tester.widget<Text>(find.text(long));
        final rich = tester.widget<RichText>(
          find.descendant(of: find.text(long), matching: find.byType(RichText)),
        );
        final painter = TextPainter(
          text: rich.text,
          textDirection: TextDirection.ltr,
          textScaler: TextScaler.linear(scale),
          textHeightBehavior: title.textHeightBehavior,
        )..layout(maxWidth: tester.getSize(find.text(long)).width);
        final lines = painter.computeLineMetrics();
        expect(lines.length, greaterThan(1));
        for (final line in lines) {
          expect(line.height, closeTo(24 * scale, .001));
        }
        for (var index = 1; index < lines.length; index++) {
          expect(
            lines[index].baseline - lines[index - 1].baseline,
            // SkParagraph rounds the trimmed last-line baseline by up to
            // half a logical pixel; every nominal line height stays exact.
            closeTo(24 * scale, index == lines.length - 1 ? .501 : .001),
          );
        }
        expect(rich.text.toPlainText(), long);
        painter.dispose();
        await tester.tap(find.byKey(const ValueKey('option:title-fixture:0')));
        await tester.pump();
        expect(selected, 0);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
