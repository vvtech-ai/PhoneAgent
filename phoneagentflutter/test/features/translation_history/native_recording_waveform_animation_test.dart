import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/translation_history/presentation/widgets/native_recording_waveform.dart';

List<double> levels(WidgetTester tester) =>
    (tester
                .widget<CustomPaint>(
                  find.descendant(
                    of: find.byType(NativeRecordingWaveform),
                    matching: find.byType(CustomPaint),
                  ),
                )
                .painter!
            as NativeRecordingWaveformPainter)
        .levels;

void main() {
  testWidgets('display frames follow play pause resume and completion', (
    tester,
  ) async {
    var playing = false, paused = false;
    late StateSetter update;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return NativeRecordingWaveform(playing: playing, paused: paused);
          },
        ),
      ),
    );
    final resting = levels(tester);
    await tester.pump(const Duration(seconds: 1));
    expect(levels(tester), same(resting));
    update(() => playing = true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 67));
    final first = levels(tester);
    expect(first.length, 24);
    expect(first.first, closeTo(.41295, .000001));
    expect(first, everyElement(inInclusiveRange(.12, .68)));
    await tester.pump(const Duration(milliseconds: 67));
    expect(levels(tester), isNot(equals(first)));
    update(() {
      playing = false;
      paused = true;
    });
    await tester.pump();
    final frozen = levels(tester);
    await tester.pump(const Duration(seconds: 1));
    expect(levels(tester), same(frozen));
    update(() {
      playing = true;
      paused = false;
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 67));
    expect(levels(tester), isNot(equals(frozen)));
    update(() => playing = false);
    await tester.pump();
    expect(levels(tester), same(resting));
    update(() => playing = true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 67));
    expect(levels(tester), equals(first));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('hidden and reduced animation hosts stop display work', (
    tester,
  ) async {
    var visible = true, reduce = false;
    late StateSetter update;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: reduce),
              child: TickerMode(
                enabled: visible,
                child: const NativeRecordingWaveform(playing: true),
              ),
            );
          },
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 67));
    update(() => visible = false);
    await tester.pump();
    final frozen = levels(tester);
    await tester.pump(const Duration(seconds: 1));
    expect(levels(tester), same(frozen));
    update(() => visible = true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 67));
    expect(levels(tester), isNot(equals(frozen)));
    update(() => reduce = true);
    await tester.pump();
    expect(levels(tester), same(NativeRecordingWaveformPainter.defaultLevels));
    await tester.pump(const Duration(seconds: 1));
    expect(levels(tester), same(NativeRecordingWaveformPainter.defaultLevels));
    update(() => reduce = false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 67));
    expect(levels(tester).first, closeTo(.41295, .000001));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('background stops display timer and foreground resumes', (
    tester,
  ) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(
      const MaterialApp(home: NativeRecordingWaveform(playing: true)),
    );
    await tester.pump(const Duration(milliseconds: 67));
    final frozen = levels(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump(const Duration(seconds: 1));
    expect(levels(tester), same(frozen));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 67));
    expect(levels(tester), isNot(equals(frozen)));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });
}
