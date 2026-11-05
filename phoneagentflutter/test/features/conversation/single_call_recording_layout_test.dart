import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/design/recording_tokens.dart';
import 'package:phone_agent/features/conversation/domain/receipts/call_receipt.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/receipts/call_receipt_card.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/receipts/call_recording_control.dart';
import 'package:phone_agent/features/translation_history/presentation/controller/recording_audio_controller.dart';
import 'package:phone_agent/features/translation_history/presentation/widgets/native_recording_waveform.dart';

const _nativeIdleLevels = <double>[
  .35,
  .72,
  .92,
  .48,
  .82,
  .60,
  .96,
  .52,
  .76,
  .40,
  .88,
  .66,
  1,
  .54,
  .84,
  .44,
  .90,
  .62,
  .78,
  .38,
  .86,
  .56,
  .94,
  .70,
];

Finder surface(bool Function(BoxDecoration) matches) => find.byWidgetPredicate(
  (widget) =>
      widget is Container &&
      widget.decoration is BoxDecoration &&
      matches(widget.decoration! as BoxDecoration),
);

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final width in [320.0, 390.0]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets(
          'single recording shares transcript/result bounds $platform/$width/$scale',
          (tester) async {
            tester.view.physicalSize = Size(width, 900);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);
            var plays = 0, saves = 0;
            await tester.pumpWidget(
              MaterialApp(
                theme: ThemeData(platform: platform, useMaterial3: true),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: Scaffold(
                  body: SingleChildScrollView(
                    padding: const EdgeInsets.all(18),
                    child: CallReceiptCard(
                      receipt: CallReceipt(
                        attemptId: 'synthetic',
                        status: 'COMPLETED',
                        transcript: 'AI：合成内容',
                        metadata: const {
                          'callId': 'synthetic',
                          'agentOutcome': 'SUCCESS',
                        },
                      ),
                      recordingBuilder: (_, compact) => CallRecordingControl(
                        state: const RecordingAudioState(
                          phase: RecordingAudioPhase.ready,
                          durationMillis: 60000,
                        ),
                        compact: compact,
                        onPrimary: () => plays++,
                        onSave: () => saves++,
                      ),
                    ),
                  ),
                ),
              ),
            );
            final blue = tester.getRect(
              surface((d) => d.color == RecordingTokens.blue),
            );
            final transcript = tester.getRect(
              surface((d) => d.color == Colors.white),
            );
            final result = tester.getRect(surface((d) => d.gradient != null));
            expect(blue.left, transcript.left);
            expect(blue.right, transcript.right);
            expect(blue.left, result.left);
            expect(blue.right, result.right);
            expect(blue.width, 280);
            if (scale == 1) expect(blue.height, 81);
            expect(result.top - blue.bottom, 8);
            await tester.ensureVisible(
              find.byKey(const ValueKey('recording-primary')),
            );
            await tester.tap(find.byKey(const ValueKey('recording-primary')));
            await tester.tap(find.byKey(const ValueKey('recording-save')));
            expect(plays, 1);
            expect(saves, 1);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }

  testWidgets(
    'idle is static native shape; real frames freeze only while paused',
    (tester) async {
      var audio = const RecordingAudioState();
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return CallRecordingControl(
                  state: audio,
                  compact: false,
                  onPrimary: () {},
                  onSave: () {},
                );
              },
            ),
          ),
        ),
      );
      List<double>? levels() => tester
          .widget<NativeRecordingWaveform>(find.byType(NativeRecordingWaveform))
          .levels;
      expect(levels(), _nativeIdleLevels);
      final first = List.generate(24, (i) => .2 + i / 40);
      update(
        () => audio = RecordingAudioState(
          phase: RecordingAudioPhase.playing,
          waveform: first,
        ),
      );
      await tester.pump();
      expect(levels(), first);
      await tester.pump(const Duration(seconds: 1));
      expect(levels(), first, reason: 'No clock-generated amplitude');
      update(
        () => audio = const RecordingAudioState(
          phase: RecordingAudioPhase.paused,
        ),
      );
      await tester.pump();
      expect(levels(), first);
      update(
        () => audio = RecordingAudioState(
          phase: RecordingAudioPhase.paused,
          waveform: List.filled(24, .12),
        ),
      );
      await tester.pump();
      expect(
        levels(),
        first,
        reason: 'Native pause reset must not erase the displayed last frame',
      );
      update(() => audio = const RecordingAudioState());
      await tester.pump();
      expect(levels(), _nativeIdleLevels);
      update(
        () => audio = const RecordingAudioState(
          phase: RecordingAudioPhase.paused,
        ),
      );
      await tester.pump();
      expect(levels(), _nativeIdleLevels, reason: 'Idle cleared old frame');
    },
  );
}
