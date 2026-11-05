import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/translation/domain/translation_call_view.dart';
import 'package:phone_agent/features/translation/presentation/pages/translation_call_page.dart';
import 'package:phone_agent/features/translation/presentation/widgets/translation_call_controls.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      'compact 2x call follows updated latest transcript on $platform',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var records = List.generate(
          30,
          (i) => TranslationTranscript(
            id: '$i',
            leg: 'local',
            source: '字幕$i',
            translated: 'translation $i',
          ),
        );
        Future<void> render() {
          final state = TranslationCallView(
            phase: TranslationPhase.translating,
            dialPad: true,
            transcripts: records,
          );
          return tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(platform: platform),
              home: MediaQuery(
                data: const MediaQueryData(textScaler: TextScaler.linear(2)),
                child: TranslationCallPage(
                  state: state,
                  target: '合成联系人',
                  controls: TranslationCallControls(
                    state: state,
                    onMute: () {},
                    onSpeaker: () {},
                    onPad: () {},
                    onDigit: (_) {},
                    onHangup: () {},
                  ),
                ),
              ),
            ),
          );
        }

        ScrollPosition position() => tester
            .state<ScrollableState>(
              find.descendant(
                of: find.byType(ListView).first,
                matching: find.byType(Scrollable),
              ),
            )
            .position;
        await render();
        await tester.pumpAndSettle();
        expect(find.text('字幕29').hitTestable(), findsOneWidget);
        final atLatest = position().pixels;
        position().jumpTo(atLatest == 0 ? position().maxScrollExtent : 0);
        await tester.pump();
        final oldPosition = position().pixels;
        await render();
        await tester.pump();
        expect(position().pixels, oldPosition);
        records = [
          ...records.take(29),
          const TranslationTranscript(
            id: '29',
            leg: 'local',
            source: '最新字幕补全',
            translated: 'latest final',
            isFinal: true,
          ),
        ];
        await render();
        await tester.pumpAndSettle();
        expect(position().pixels, atLatest);
        expect(find.text('最新字幕补全').hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
