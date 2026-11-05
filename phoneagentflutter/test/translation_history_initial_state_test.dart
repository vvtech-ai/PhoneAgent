import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/translation_history/presentation/controller/translation_history_controller.dart';
import 'package:phone_agent/features/translation_history/presentation/pages/translation_history_page.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('initial history states $platform $scale', (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        var closed = 0, retried = 0;
        Future<void> show(TranslationHistoryState state) async {
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(
                platform: platform,
                textTheme: const TextTheme(
                  bodyMedium: TextStyle(letterSpacing: 9, height: 3),
                ),
              ),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: Scaffold(
                body: TranslationHistoryPage(
                  state: state,
                  onClose: () => closed++,
                  onRetry: () => retried++,
                ),
              ),
            ),
          );
          await tester.pump();
        }

        await show(const TranslationHistoryState(loading: true));
        expect(find.text('正在加载记录'), findsOneWidget);
        expect(tester.getTopLeft(find.text('正在加载记录')).dy, 28);
        expect(find.text('翻译通话记录'), findsNothing);
        expect(
          tester.getRect(find.text('正在加载记录')).right,
          lessThanOrEqualTo(
            tester
                .getRect(find.byKey(const ValueKey('close-translation')))
                .left,
          ),
        );
        expect(find.byType(LinearProgressIndicator), findsNothing);
        expect(find.byKey(const ValueKey('retry-translation')), findsNothing);
        expect(
          tester
              .getSize(find.byKey(const ValueKey('close-translation')))
              .height,
          greaterThanOrEqualTo(48),
        );
        await tester.tap(find.byKey(const ValueKey('close-translation')));
        expect(closed, 1);
        await show(const TranslationHistoryState(failed: true));
        expect(find.text('正在加载记录'), findsNothing);
        expect(find.text('记录加载失败'), findsOneWidget);
        expect(find.text('重试'), findsOneWidget);
        expect(find.text('翻译通话记录'), findsNothing);
        final message = tester.getRect(find.text('记录加载失败'));
        final retry = tester.getRect(
          find.byKey(const ValueKey('retry-translation')),
        );
        expect(retry.top - message.bottom, 12);
        expect(retry.height, greaterThanOrEqualTo(48));
        expect((message.top + retry.bottom) / 2, closeTo(284, .01));
        await tester.tap(find.byKey(const ValueKey('retry-translation')));
        expect(retried, 1);
        await show(const TranslationHistoryState(loading: true));
        expect(find.text('记录加载失败'), findsNothing);
        expect(find.text('正在加载记录'), findsOneWidget);
        await show(
          const TranslationHistoryState(
            content: TranslationHistoryContent(
              '合成对象',
              '+12025550123',
              '今天 11:00',
              '00:12',
              [TranslationRow(true, '请确认时间。', 'Please confirm.')],
              false,
            ),
          ),
        );
        expect(find.text('正在加载记录'), findsNothing);
        expect(find.text('记录加载失败'), findsNothing);
        expect(find.text('合成对象'), findsOneWidget);
        expect(find.text('请确认时间。'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}
