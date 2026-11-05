import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/settings_providers.dart';
import 'package:phone_agent/features/settings/domain/original_audio_settings.dart';
import 'package:phone_agent/features/settings/presentation/pages/original_audio_page.dart';

class _MemoryAudio implements OriginalAudioStore {
  @override
  Future<OriginalAudioSettings> read() async =>
      const OriginalAudioSettings(enabled: true);
  @override
  Future<void> write(OriginalAudioSettings value) async {}
}

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        '$platform original typography rejects inherited spacing $scale',
        (tester) async {
          tester.view.physicalSize = const Size(320, 568);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                originalAudioStoreProvider.overrideWithValue(_MemoryAudio()),
              ],
              child: MaterialApp(
                theme: ThemeData(
                  platform: platform,
                  textTheme: const TextTheme(
                    bodyMedium: TextStyle(
                      fontSize: 16,
                      height: 3,
                      letterSpacing: 7,
                    ),
                  ),
                ),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: const OriginalAudioPage(),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final expected = <String, (double, double)>{
            '播放原声': (16, 19),
            '开启后先播放通话原声；译音播放时按下方比例混合当前实时原声。': (13, 18),
            '纯原声播放声音大小：100%': (14, 20),
            '混声时原声比例：50%': (14, 20),
            '均按 10% 步进调节，仅影响下一通实时翻译通话。': (12, 18),
          };
          for (final entry in expected.entries) {
            final style = tester.widget<Text>(find.text(entry.key)).style!;
            expect(style.fontSize, entry.value.$1);
            expect(style.height, entry.value.$2 / entry.value.$1);
            expect(style.letterSpacing, 0);
          }
          expect(
            tester.getSize(find.text('播放原声')).height,
            closeTo(19 * scale, .01),
          );
          for (final key in [
            'original-enabled',
            'original-volume',
            'original-gain',
          ]) {
            await tester.ensureVisible(find.byKey(Key(key)));
            await tester.pumpAndSettle();
            expect(
              tester.getSize(find.byKey(Key(key))).height,
              greaterThanOrEqualTo(48),
            );
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
