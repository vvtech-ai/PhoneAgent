import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/settings/presentation/widgets/native_original_audio_controls.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        '$platform original levels physical steps and disabled $scale',
        (tester) async {
          tester.view.physicalSize = const Size(320, 568);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          var volume = 0, gain = 0, changes = 0, enabled = true;
          Future<void> show() async {
            await tester.pumpWidget(
              MaterialApp(
                theme: ThemeData(platform: platform),
                home: MediaQuery(
                  data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                  child: Scaffold(
                    body: Padding(
                      padding: const EdgeInsets.all(30),
                      child: StatefulBuilder(
                        builder: (context, update) => Column(
                          children: [
                            NativeAudioLevel(
                              label: '纯原声播放声音大小',
                              value: volume,
                              max: 100,
                              sliderKey: const Key('volume'),
                              onChanged: enabled
                                  ? (v) => update(() {
                                      volume = v.round();
                                      changes++;
                                    })
                                  : null,
                            ),
                            NativeAudioLevel(
                              label: '混声时原声比例',
                              value: gain,
                              max: 50,
                              sliderKey: const Key('gain'),
                              onChanged: enabled
                                  ? (v) => update(() {
                                      gain = v.round();
                                      changes++;
                                    })
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
          }

          await show();
          for (final entry in {'volume': 100, 'gain': 50}.entries) {
            final slider = find.byKey(Key(entry.key));
            expect(tester.getSize(slider).height, greaterThanOrEqualTo(48));
            final rect = tester.getRect(slider);
            for (var value = 0; value <= entry.value; value += 10) {
              final fraction = value / entry.value;
              await tester.tapAt(
                Offset(
                  rect.left + 13 + (rect.width - 26) * fraction,
                  rect.center.dy,
                ),
              );
              await tester.pumpAndSettle();
              expect(entry.key == 'volume' ? volume : gain, value);
            }
          }
          final before = changes;
          enabled = false;
          await show();
          await tester.tap(find.byKey(const Key('volume')));
          await tester.tap(find.byKey(const Key('gain')));
          await tester.pumpAndSettle();
          expect(changes, before);
          expect(volume, 100);
          expect(gain, 50);
          expect(
            tester.widget<Slider>(find.byKey(const Key('gain'))).onChanged,
            isNull,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
