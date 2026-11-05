import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/translation_history/presentation/controller/recording_audio_controller.dart';
import 'package:phone_agent/features/translation_history/presentation/widgets/recording_audio_card.dart';
import 'package:phone_agent/features/translation_history/presentation/widgets/native_recording_waveform.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final large in [false, true]) {
      testWidgets('$platform recording waveform layout large=$large', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = large
            ? const Size(320, 568)
            : const Size(390, 720);
        addTearDown(tester.view.reset);
        var plays = 0, saves = 0;
        var state = const RecordingAudioState(
          phase: RecordingAudioPhase.ready,
          durationMillis: 120000,
        );
        late StateSetter rebuild;
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
              body: StatefulBuilder(
                builder: (context, setState) {
                  rebuild = setState;
                  return RecordingAudioCard(
                    state: state,
                    onPrimary: () => plays++,
                    onSave: () => saves++,
                  );
                },
              ),
            ),
          ),
        );
        final wave = tester.getRect(find.byType(NativeRecordingWaveform));
        final primary = find.byKey(const ValueKey('recording-primary'));
        final control = tester.getRect(primary);
        expect(wave.height, 38);
        expect(wave.width, greaterThan(32));
        expect(control.shortestSide, greaterThanOrEqualTo(48));
        expect(find.text('02:00'), findsOneWidget);
        if (large) {
          expect(wave.top, greaterThanOrEqualTo(control.bottom));
        } else {
          final textColumn = find.byWidgetPredicate(
            (w) => w is SizedBox && w.width == 84,
          );
          expect(textColumn, findsOneWidget);
          expect(wave.left - tester.getRect(textColumn).right, closeTo(6, .1));
          expect(control.left - wave.right, closeTo(8, .1));
          expect(wave.center.dy, closeTo(control.center.dy, .1));
          final card = tester.getRect(
            find
                .ancestor(
                  of: find.byType(NativeRecordingWaveform),
                  matching: find.byType(Container),
                )
                .first,
          );
          expect(wave.center.dy, closeTo(card.center.dy, .1));
        }
        await tester.tap(find.byTooltip('播放录音'));
        await tester.tap(find.byTooltip('保存录音'));
        expect(plays, 1);
        expect(saves, 1);
        rebuild(
          () => state = const RecordingAudioState(
            phase: RecordingAudioPhase.processing,
            busy: true,
          ),
        );
        await tester.pump();
        expect(tester.widget<IconButton>(primary).onPressed, isNull);
        expect(
          tester
              .widget<IconButton>(find.byKey(const ValueKey('recording-save')))
              .onPressed,
          isNull,
        );
        rebuild(
          () => state = const RecordingAudioState(
            phase: RecordingAudioPhase.failed,
          ),
        );
        await tester.pump();
        await tester.tap(find.byTooltip('重试加载录音'));
        expect(plays, 2);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
