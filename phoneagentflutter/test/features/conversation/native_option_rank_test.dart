import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/conversation_messages.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/conversation_option_content.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final scale in [1.0, 2.0]) {
      for (final restaurant in [false, true]) {
        testWidgets('$platform rank $restaurant fits at $scale', (
          tester,
        ) async {
          final option = ConversationMessages.options({
            'items': [
              {'label': '合成候选', if (restaurant) 'rating': 4.7},
            ],
          }).single;
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(platform: platform),
              home: Scaffold(
                body: MediaQuery(
                  data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                  child: SizedBox(
                    width: 242,
                    child: ConversationOptionContent(index: 0, option: option),
                  ),
                ),
              ),
            ),
          );
          final circle = find.byWidgetPredicate(
            (widget) =>
                widget is Container &&
                widget.decoration is BoxDecoration &&
                (widget.decoration! as BoxDecoration).shape == BoxShape.circle,
          );
          final bounds = tester.getRect(circle);
          final number = tester.getRect(find.text('1'));
          expect(bounds.width, closeTo(bounds.height, .001));
          expect(number.top, greaterThanOrEqualTo(bounds.top));
          expect(number.bottom, lessThanOrEqualTo(bounds.bottom));
          if (scale == 1) expect(bounds.width, 26);
          if (scale > 1) expect(bounds.width, greaterThan(26));
          if (restaurant) {
            final score = tester
                .widgetList<RichText>(find.byType(RichText))
                .singleWhere((text) => text.text.toPlainText() == '4.7分');
            TextSpan? span;
            void visit(InlineSpan current) {
              if (current is TextSpan) {
                if (current.text == '4.7分') span = current;
                for (final child in current.children ?? const <InlineSpan>[]) {
                  visit(child);
                }
              }
            }

            visit(score.text);
            expect(span!.style!.fontSize, 12);
            expect(span!.style!.height, 16 / 12);
          }
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}
