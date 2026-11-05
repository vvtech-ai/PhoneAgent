import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/translation/domain/translation_call_view.dart';
import 'package:phone_agent/features/translation/presentation/widgets/translation_transcript_thread.dart';

TranslationTranscript item(
  int i, {
  String suffix = '',
  bool finalText = false,
}) => TranslationTranscript(
  id: '$i',
  leg: 'merchant',
  source: 'Hello $i$suffix',
  translated: '您好，这是第 $i 条字幕$suffix',
  sourceLanguage: 'en',
  translatedLanguage: 'zh',
  isFinal: finalText,
);

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'latest updates follow; unrelated rebuild preserves $platform/$scale',
        (tester) async {
          var records = List.generate(30, item);
          Future<void> render() => tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(platform: platform),
              home: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                child: Scaffold(
                  body: SizedBox(
                    key: const ValueKey('thread-area'),
                    width: 320,
                    height: 300,
                    child: TranslationTranscriptThread(transcripts: records),
                  ),
                ),
              ),
            ),
          );
          double offset() => tester
              .state<ScrollableState>(find.byType(Scrollable))
              .position
              .pixels;
          Future<void> readEarlier() async {
            await tester.drag(find.byType(ListView), const Offset(0, 220));
            await tester.pumpAndSettle();
            expect(offset(), greaterThan(0));
          }

          await render();
          expect(offset(), 0);
          await readEarlier();
          final previous = offset();
          await render();
          await tester.pump();
          expect(offset(), previous);
          // An older correction does not change the native latest-scroll key.
          records = [item(0, suffix: '修正'), ...records.skip(1)];
          await render();
          await tester.pump();
          expect(offset(), previous);
          for (final update in [
            item(30),
            item(30, suffix: '更新'),
            item(30, suffix: '更新', finalText: true),
          ]) {
            records = [...records.take(30), update];
            await render();
            await tester.pump();
            expect(offset(), 0);
            expect(find.text(update.primary), findsOneWidget);
            await readEarlier();
          }
          await tester.pumpWidget(const SizedBox());
          await tester.pump();
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  testWidgets('remote bubble is translucent and latest has no trailing gap', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            key: const ValueKey('short-thread-area'),
            height: 300,
            child: TranslationTranscriptThread(transcripts: [item(0)]),
          ),
        ),
      ),
    );
    expect(
      tester.getRect(find.byType(ListView)).top,
      tester.getRect(find.byKey(const ValueKey('short-thread-area'))).top,
    );
    expect(tester.getSize(find.byType(ListView)).height, lessThan(300));
    final bubble = find.byKey(const ValueKey('merchant:0'));
    final decoration =
        tester.widget<Container>(bubble).decoration! as BoxDecoration;
    expect(decoration.color, const Color(0xF0FFFFFF));
    expect(
      tester.widget<Text>(find.text('Hello 0')).style!.color,
      const Color(0xB3111111),
    );
    expect(
      tester.getRect(bubble).bottom,
      tester.getRect(find.byType(ListView)).bottom,
    );
  });
}
