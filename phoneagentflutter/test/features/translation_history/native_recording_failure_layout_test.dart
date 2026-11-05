import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/translation_history/presentation/controller/recording_audio_controller.dart';
import 'package:phone_agent/features/translation_history/presentation/widgets/recording_audio_card.dart';
import 'package:phone_agent/features/translation_history/presentation/widgets/native_recording_waveform.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final large in [false, true]) {
      testWidgets('$platform compact recording failure large=$large', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(320, 568);
        addTearDown(tester.view.reset);
        var retries = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: platform),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(large ? 2 : 1)),
              child: child!,
            ),
            home: Scaffold(
              body: RecordingAudioCard(
                state: const RecordingAudioState(
                  phase: RecordingAudioPhase.failed,
                  message: '音频加载失败',
                ),
                onPrimary: () => retries++,
                onSave: () {},
              ),
            ),
          ),
        );
        expect(find.text('通话录音'), findsOneWidget);
        expect(find.text('音频加载失败'), findsOneWidget);
        final wave = tester.getRect(find.byType(NativeRecordingWaveform));
        expect(wave.height, 30);
        final blue = find
            .ancestor(
              of: find.byType(NativeRecordingWaveform),
              matching: find.byType(Container),
            )
            .first;
        final card = tester.getRect(blue);
        final decoration =
            tester.widget<Container>(blue).decoration! as BoxDecoration;
        expect(decoration.borderRadius, BorderRadius.circular(16));
        if (!large) {
          expect(card.height, 64);
          expect(wave.center.dy, closeTo(card.center.dy, .1));
        } else {
          expect(card.height, greaterThanOrEqualTo(64));
        }
        final primary = find.byKey(const ValueKey('recording-primary'));
        expect(tester.getSize(primary).shortestSide, greaterThanOrEqualTo(48));
        final circle = find.descendant(
          of: primary,
          matching: find.byWidgetPredicate(
            (w) => w is SizedBox && w.width == 40 && w.height == 40,
          ),
        );
        expect(circle, findsOneWidget);
        expect(tester.getSize(circle), const Size(40, 40));
        await tester.tap(find.byTooltip('重试加载录音'));
        expect(retries, 1);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
