import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/translation_history/presentation/pages/translation_history_page.dart';
import 'package:phone_agent/features/translation_history/presentation/controller/translation_history_controller.dart';
import 'package:phone_agent/features/translation_history/presentation/controller/recording_audio_controller.dart';
import 'package:phone_agent/features/translation_history/presentation/widgets/recording_audio_card.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      'recording stays floating and last subtitle clears overlay on $platform',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var plays = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: platform),
            home: Scaffold(
              body: SafeArea(
                child: TranslationHistoryPage(
                  state: TranslationHistoryState(
                    content: TranslationHistoryContent(
                      'Synthetic',
                      '',
                      '今天 10:00',
                      '02:00',
                      [
                        for (var i = 0; i < 30; i++)
                          TranslationRow(false, '字幕$i', 'Subtitle$i'),
                      ],
                      true,
                    ),
                  ),
                  onClose: () {},
                  onRetry: () {},
                  recording: RecordingAudioCard(
                    state: const RecordingAudioState(
                      phase: RecordingAudioPhase.ready,
                      durationMillis: 120000,
                    ),
                    onPrimary: () => plays++,
                    onSave: () {},
                  ),
                ),
              ),
            ),
          ),
        );
        final button = find.byKey(const ValueKey('recording-primary'));
        final initial = tester.getRect(button);
        await tester.drag(find.byType(ListView), const Offset(0, -8000));
        await tester.pumpAndSettle();
        expect(tester.getRect(button), initial);
        final scrim = find.byKey(const ValueKey('translation-recording-scrim'));
        expect(
          tester.getBottomLeft(find.text('Subtitle29')).dy,
          lessThanOrEqualTo(tester.getTopLeft(scrim).dy),
        );
        await tester.tap(button);
        expect(plays, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
