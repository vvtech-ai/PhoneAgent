import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/recording_playback_arbiter.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/receipts/preview_call_recording.dart';

void main() {
  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets(
      'shared full and compact controls are mutually exclusive at $width',
      (tester) async {
        await tester.binding.setSurfaceSize(Size(width, 720));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final arbiter = RecordingPlaybackArbiter();
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  PreviewCallRecording(compact: false, arbiter: arbiter),
                  PreviewCallRecording(compact: true, arbiter: arbiter),
                ],
              ),
            ),
          ),
        );
        await tester.tap(find.byKey(const ValueKey('recording-primary')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump();
        expect(find.byTooltip('暂停录音'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('receipt-recording-play')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump();
        expect(find.byTooltip('暂停录音'), findsNothing);
        expect(find.byTooltip('播放录音'), findsOneWidget);
        expect(find.byTooltip('暂停本次电话录音'), findsOneWidget);
        await arbiter.stop();
        await tester.pump();
        expect(find.byTooltip('暂停本次电话录音'), findsNothing);
        expect(find.byTooltip('播放本次电话录音'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      },
    );
  }
}
