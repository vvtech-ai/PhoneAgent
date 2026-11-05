import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/call_models/domain/call_models.dart';
import 'package:phone_agent/features/call_models/presentation/controller/call_model_controller.dart';
import 'package:phone_agent/features/call_models/presentation/pages/call_voices_page.dart';
import 'package:phone_agent/features/call_models/presentation/widgets/voice_sheet_frame.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        '$platform voice sheet content height and last action $scale',
        (tester) async {
          tester.view.physicalSize = const Size(390, 780);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          var selected = '', previews = 0;
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(platform: platform),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(scale),
                  padding: const EdgeInsets.only(bottom: 48),
                  viewPadding: const EdgeInsets.only(bottom: 48),
                ),
                child: child!,
              ),
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () => showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      builder: (sheetContext) => VoiceSheetFrame(
                        child: CallVoicesPage(
                          state: const CallModelState(
                            voiceProvider: 'QWEN_OMNI_PLUS',
                            voices: CallVoiceCatalog('Andre', 'AI', [
                              CallVoice('Andre', 'Andre', '合成样音', true),
                              CallVoice('Ethan', 'Ethan', '合成样音', false),
                              CallVoice('Katerina', 'Katerina', '合成样音', false),
                            ]),
                          ),
                          onBack: () => Navigator.pop(sheetContext),
                          onRetry: () {},
                          onSelect: (voice) => selected = voice.id,
                          onSelectClone: () {},
                          onCreateClone: () {},
                          onPreview: (_) => previews++,
                        ),
                      ),
                    ),
                    child: const Text('打开'),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('打开'));
          await tester.pumpAndSettle();
          final page = find.byType(CallVoicesPage);
          if (scale == 1) {
            expect(tester.getSize(page).height, lessThan(600));
          } else {
            expect(tester.getSize(page).height, lessThanOrEqualTo(640));
            await tester.scrollUntilVisible(
              find.byKey(const ValueKey('voice-Katerina')),
              120,
              scrollable: find.byType(Scrollable).last,
            );
            await tester.drag(find.byType(ListView), const Offset(0, -240));
            await tester.pumpAndSettle();
          }
          final last = find.byKey(const ValueKey('voice-Katerina'));
          expect(tester.getRect(last).bottom, lessThanOrEqualTo(732));
          await tester.tap(find.text('Katerina'));
          await tester.pumpAndSettle();
          expect(selected, 'Katerina');
          expect(previews, 0);
          final close = find.byKey(const ValueKey('backFromVoiceIdentity'));
          expect(tester.getSize(close), const Size(48, 48));
          await tester.tap(close);
          await tester.pumpAndSettle();
          expect(page, findsNothing);
          expect(find.text('打开'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
