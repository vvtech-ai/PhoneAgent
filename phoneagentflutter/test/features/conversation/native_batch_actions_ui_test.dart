import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/receipts/batch_receipt.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/receipts/batch_receipt_card.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/receipts/call_recording_control.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/receipts/native_compact_recording_glyph.dart';
import 'package:phone_agent/features/translation_history/presentation/controller/recording_audio_controller.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      'batch actions share row and preserve playback gates $platform',
      (tester) async {
        tester.view.physicalSize = const Size(320, 390);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        var expanded = false;
        for (final phase in [
          RecordingAudioPhase.idle,
          RecordingAudioPhase.loading,
          RecordingAudioPhase.playing,
          RecordingAudioPhase.failed,
        ]) {
          var plays = 0;
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(platform: platform),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(2)),
                child: child!,
              ),
              home: Scaffold(
                body: SingleChildScrollView(
                  child: SizedBox(
                    width: 240,
                    child: BatchReceiptItemCard(
                      item: BatchReceiptItem.fromJson({
                        'itemId': 'same',
                        'targetName': '合成',
                        'status': 'SUCCESS',
                        'callId': 'call',
                        'transcript': 'AI：合成记录',
                      }, 'same'),
                      recordingBuilder: (_, compact) => CallRecordingControl(
                        state: RecordingAudioState(phase: phase),
                        compact: compact,
                        onPrimary: () => plays++,
                        onSave: () => fail('compact has no save'),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pump();
          final play = find.byKey(const ValueKey('receipt-recording-play'));
          final transcript = find.byKey(
            const ValueKey('receipt-transcript:same'),
          );
          expect(
            tester.getRect(play).center.dy,
            closeTo(tester.getRect(transcript).center.dy, .01),
          );
          expect(find.byTooltip('保存录音'), findsNothing);
          expect(find.text('合成记录'), expanded ? findsOneWidget : findsNothing);
          final blue = find.descendant(
            of: play,
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is Container &&
                  widget.constraints?.maxWidth == 24 &&
                  widget.constraints?.maxHeight == 24,
            ),
          );
          expect(blue, findsOneWidget);
          if (phase == RecordingAudioPhase.loading) {
            expect(find.byType(NativeCompactRecordingGlyph), findsNothing);
          } else {
            expect(
              tester
                  .widget<NativeCompactRecordingGlyph>(
                    find.byType(NativeCompactRecordingGlyph),
                  )
                  .shape,
              phase == RecordingAudioPhase.playing
                  ? NativeCompactRecordingShape.pause
                  : phase == RecordingAudioPhase.failed
                  ? NativeCompactRecordingShape.retry
                  : NativeCompactRecordingShape.play,
            );
          }
          await tester.tap(play);
          expect(plays, phase == RecordingAudioPhase.loading ? 0 : 1);
          if (phase != RecordingAudioPhase.loading) {
            await tester.tap(transcript);
            await tester.pump();
            expanded = !expanded;
            expect(find.text('合成记录'), expanded ? findsOneWidget : findsNothing);
          }
          expect(tester.takeException(), isNull);
        }
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
