import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../tool/native_ui_reference/flutter_history_content_reference.dart'
    as fixture;

void main() {
  for (final large in [false, true]) {
    for (final empty in [false, true]) {
      testWidgets(
        'formal history content reference closes without audio ports large=$large empty=$empty',
        (tester) async {
          fixture.main(largeText: large, empty: empty);
          await tester.pumpAndSettle();
          expect(find.text('合成翻译对象'), findsOneWidget);
          expect(find.text('+12025550123'), findsOneWidget);
          expect(
            MediaQuery.textScalerOf(
              tester.element(find.text('+12025550123')),
            ).scale(14),
            large ? 28 : 14,
          );
          expect(tester.takeException(), isNull);
          expect(find.text('暂无有效字幕'), empty ? findsOneWidget : findsNothing);
          if (empty) {
            expect(tester.getSize(find.text('暂无有效字幕')).height, large ? 34 : 17);
          }
          expect(
            find.text('请确认今天的营业时间。'),
            empty ? findsNothing : findsOneWidget,
          );
          if (!large && !empty) {
            expect(find.text('今天营业到晚上八点。'), findsOneWidget);
          }
          expect(find.byKey(const ValueKey('recording-primary')), findsNothing);
          await tester.tap(find.byKey(const ValueKey('close-translation')));
          await tester.pumpAndSettle();
          expect(find.text('合成历史展示已返回'), findsOneWidget);
          expect(find.text('请确认今天的营业时间。'), findsNothing);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
  for (final large in [false, true]) {
    testWidgets('initial error retry reaches content large=$large', (
      tester,
    ) async {
      fixture.main(largeText: large, initial: 'error');
      await tester.pumpAndSettle();
      expect(find.text('记录加载失败'), findsOneWidget);
      expect(find.text('合成翻译对象'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('retry-translation')));
      await tester.pump();
      expect(find.text('正在加载记录'), findsOneWidget);
      expect(find.text('记录加载失败'), findsNothing);
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('合成翻译对象'), findsOneWidget);
      expect(find.text('正在加载记录'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('close-translation')));
      await tester.pumpAndSettle();
      expect(find.text('合成历史展示已返回'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });
    testWidgets(
      'initial error retry cannot revive closed fixture large=$large',
      (tester) async {
        fixture.main(largeText: large, initial: 'error');
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('retry-translation')));
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('close-translation')));
        await tester.pump(const Duration(seconds: 3));
        expect(find.text('合成历史展示已返回'), findsOneWidget);
        expect(find.text('合成翻译对象'), findsNothing);
        expect(find.text('正在加载记录'), findsNothing);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
    testWidgets('initial loading remains closable large=$large', (
      tester,
    ) async {
      fixture.main(largeText: large, initial: 'loading');
      await tester.pumpAndSettle();
      expect(find.text('正在加载记录'), findsOneWidget);
      expect(find.byKey(const ValueKey('retry-translation')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('close-translation')));
      await tester.pumpAndSettle();
      expect(find.text('合成历史展示已返回'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
