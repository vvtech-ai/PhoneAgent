import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/translation/domain/translation_call_view.dart';
import 'package:phone_agent/features/translation/presentation/widgets/translation_call_controls.dart';
import 'package:phone_agent/features/translation/presentation/widgets/translation_dtmf_pad.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('native grid, toggling and busy gates $platform/$scale', (
        tester,
      ) async {
        var state = const TranslationCallView(
          phase: TranslationPhase.translating,
          dialPad: true,
        );
        final digits = <String>[];
        final semantics = tester.ensureSemantics();
        Future<void> render({bool reduced = false}) => tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: platform),
            home: MediaQuery(
              data: MediaQueryData(
                textScaler: TextScaler.linear(scale),
                disableAnimations: reduced,
              ),
              child: Scaffold(
                body: Center(
                  child: SizedBox(
                    width: 320,
                    child: TranslationCallControls(
                      state: state,
                      onMute: () {},
                      onSpeaker: () {},
                      onPad: () {},
                      onDigit: digits.add,
                      onHangup: () {},
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await render();
        await tester.pumpAndSettle();
        final pad = find.byType(TranslationDtmfPad);
        if (platform == TargetPlatform.iOS) {
          expect(
            tester.widget<AnimatedSize>(find.byType(AnimatedSize)).duration,
            const Duration(milliseconds: 200),
          );
        } else {
          expect(find.byType(AnimatedSize), findsNothing);
        }
        expect(tester.getSize(pad).width, closeTo(320 * .72, .01));
        final one = find.byKey(const ValueKey('translation-dtmf-1'));
        final four = find.byKey(const ValueKey('translation-dtmf-4'));
        final rowHeight = scale == 1 ? 42.0 : 21 * 2 * 1.3;
        expect(tester.getSize(one), Size(64, rowHeight));
        expect(tester.getRect(four).top - tester.getRect(one).bottom, 1);
        expect(tester.getSize(pad).height, closeTo(rowHeight * 4 + 3, .01));
        final panelMaterial = tester.widget<Material>(
          find.descendant(of: pad, matching: find.byType(Material)),
        );
        expect(panelMaterial.color, const Color(0x66192B50));
        expect(panelMaterial.borderRadius, BorderRadius.circular(12));
        final mute = find.byKey(const ValueKey('translation-control-静音'));
        expect(tester.getRect(mute).top - tester.getRect(pad).bottom, 12);
        for (final digit in '123456789*0#'.split('')) {
          final key = find.byKey(ValueKey('translation-dtmf-$digit'));
          expect(tester.getSemantics(key).getSemanticsData().label, digit);
          await tester.tap(key);
        }
        expect(digits.join(), '123456789*0#');
        for (final blocked in [
          state.copy(controlsBusy: true),
          state.copy(stopping: true),
          state.copy(phase: TranslationPhase.ended),
        ]) {
          state = blocked;
          await render();
          await tester.pumpAndSettle();
          expect(tester.widget<Semantics>(one).properties.enabled, isFalse);
          await tester.tap(one);
          expect(digits.length, 12);
        }
        state = const TranslationCallView(phase: TranslationPhase.translating);
        await render();
        if (platform == TargetPlatform.iOS) {
          await tester.pump(const Duration(milliseconds: 100));
          final height = tester.getSize(find.byType(AnimatedSize)).height;
          expect(height, greaterThan(0));
          expect(height, lessThan(rowHeight * 4 + 3 + 12));
        }
        await tester.pumpAndSettle();
        expect(pad, findsNothing);
        state = state.copy(dialPad: true);
        await render(reduced: true);
        await tester.pump();
        expect(find.byType(AnimatedSize), findsNothing);
        expect(pad, findsOneWidget);
        semantics.dispose();
        expect(tester.takeException(), isNull);
      });
    }
  }
}
