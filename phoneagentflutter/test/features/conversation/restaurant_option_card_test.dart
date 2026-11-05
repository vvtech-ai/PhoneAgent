import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/conversation_messages.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/conversation_options_card.dart';

void main() {
  testWidgets(
    'same-id visible choices reset selection, equal values retain it',
    (tester) async {
      final choices = <int>[];
      Future<void> render(double rating, String phone) => tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConversationOptionsCard(
              message: ConversationMessage(
                id: 'same',
                role: MessageRole.assistant,
                text: '合成候选',
                options: ConversationMessages.options({
                  'items': [
                    {'label': '合成餐厅', 'rating': rating, 'phone': phone},
                  ],
                }),
              ),
              enabled: true,
              onSelect: (index) {
                choices.add(index);
                return true;
              },
            ),
          ),
        ),
      );
      final choice = find.byKey(const ValueKey('option:same:0'));
      await render(4.7, '00000');
      await tester.tap(choice);
      await tester.pump();
      await render(4.7, '11111');
      await tester.tap(choice);
      expect(choices, [0]);
      await render(4.8, '11111');
      await tester.tap(choice);
      expect(choices, [0, 0]);
      expect(tester.takeException(), isNull);
    },
  );
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('$platform restaurant candidates readable at $scale', (
        tester,
      ) async {
        final options = ConversationMessages.options({
          'items': [
            {
              'label': '合成餐厅与较长商家名称',
              'category': 'restaurant',
              'rating': 4.7,
              'averageCostYuan': 88,
              'cuisine': '粤菜',
              'businessArea': '合成商圈',
              'distanceMeters': 1250,
              'openingStatus': 'OPEN',
              'openingHoursToday': '10:00–22:00',
            },
            {'label': '合成未营业餐厅', 'openingStatus': 'CLOSED'},
          ],
        });
        var accepted = false;
        final choices = <int>[];
        Future<void> render(bool enabled) => tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: platform),
            home: Scaffold(
              body: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                child: SingleChildScrollView(
                  child: ConversationOptionsCard(
                    message: ConversationMessage(
                      id: 'restaurant',
                      role: MessageRole.assistant,
                      text: '请选择合成候选',
                      options: options,
                    ),
                    enabled: enabled,
                    onSelect: (index) {
                      choices.add(index);
                      return accepted;
                    },
                  ),
                ),
              ),
            ),
          ),
        );
        await render(true);
        final richTexts = tester.widgetList<RichText>(find.byType(RichText));
        final plain = richTexts.map((w) => w.text.toPlainText()).join('\n');
        expect(plain, contains('4.7分 · ¥88/人 · 粤菜'));
        expect(plain, contains('合成商圈 · 1.3km · 营业中 · 10:00–22:00'));
        expect(plain, contains('--'));
        expect(plain, contains('未营业'));
        final title = tester.widget<Text>(find.text('合成餐厅与较长商家名称'));
        expect(title.maxLines, 1);
        expect(title.overflow, TextOverflow.ellipsis);
        final details = tester.widget<Text>(
          find.byWidgetPredicate(
            (widget) =>
                widget is Text &&
                widget.textSpan?.toPlainText().startsWith('4.7分') == true,
          ),
        );
        expect(details.maxLines, 1);
        expect(details.overflow, TextOverflow.ellipsis);
        TextSpan? statusSpan;
        void visit(InlineSpan span) {
          if (span is TextSpan) {
            if (span.text == '营业中') statusSpan = span;
            for (final child in span.children ?? const <InlineSpan>[]) {
              visit(child);
            }
          }
        }

        for (final rich in richTexts) {
          visit(rich.text);
        }
        expect(statusSpan!.style!.color, const Color(0xFF16A34A));
        final first = find.byKey(const ValueKey('option:restaurant:0'));
        final second = find.byKey(const ValueKey('option:restaurant:1'));
        expect(tester.getSize(first).height, greaterThanOrEqualTo(48));
        expect(tester.takeException(), isNull);
        await tester.tap(first);
        await tester.pump();
        accepted = true;
        await tester.tap(first);
        await tester.pump();
        await tester.ensureVisible(second);
        await tester.tap(second);
        expect(choices, [0, 0]);
        await render(false);
        await tester.tap(second);
        expect(choices, [0, 0]);
        await render(true);
        await tester.tap(second);
        expect(choices, [0, 0, 1]);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
