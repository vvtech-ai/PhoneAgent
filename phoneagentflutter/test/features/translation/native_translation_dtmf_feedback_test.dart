import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/translation/data/translation_dtmf_feedback.dart';
import 'package:phone_agent/features/translation/domain/translation_call_view.dart';
import 'package:phone_agent/features/translation/presentation/widgets/translation_call_controls.dart';
import 'package:phone_agent/features/translation/presentation/pages/translation_call_page.dart';
import '../../support/translation_interactive_fixture.dart';

void main() {
  test(
    'feedback uses actual capability, preserves confirmation and busy gate',
    () async {
      var feedback = 0;
      final f = InteractiveSessionFixture(onDtmfInput: () => feedback++);
      expect(f.controller.snapshot.dtmfFeedbackAvailable, isFalse);
      await f.controller.start();
      expect(f.controller.snapshot.dtmfFeedbackAvailable, isTrue);
      await f.controller.digit('1');
      expect(feedback, 0);
      f.controller.dialPad();
      f.live.failControl = true;
      await f.controller.digit('1');
      expect(feedback, 1);
      expect(f.controller.snapshot.dtmf, isEmpty);
      f.live.failControl = false;
      f.live.controlGate = Completer<void>();
      final send = f.controller.digit('2');
      await f.controller.digit('3');
      expect(feedback, 2);
      expect(f.controller.snapshot.dtmf, isEmpty);
      f.live.controlGate!.complete();
      await send;
      expect(f.controller.snapshot.dtmf, '2');
      await f.controller.hangup();
      await f.controller.digit('4');
      expect(feedback, 2);
      await f.close();
      final fallback = InteractiveSessionFixture(onDtmfInput: () => feedback++);
      fallback.live.failConnect = true;
      await fallback.controller.start();
      expect(fallback.controller.snapshot.dtmfFeedbackAvailable, isFalse);
      fallback.controller.dialPad();
      await fallback.controller.digit('1');
      expect(feedback, 2);
      await fallback.close();
      final unavailable = InteractiveSessionFixture(
        onDtmfInput: () => throw StateError('synthetic'),
      );
      await unavailable.controller.start();
      unavailable.controller.dialPad();
      await unavailable.controller.digit('#');
      expect(unavailable.controller.snapshot.dtmf, '#');
      await unavailable.close();
    },
  );

  testWidgets(
    'Android platform adapter is optional and failure cannot escape',
    (tester) async {
      final calls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          calls.add(call);
          throw PlatformException(code: 'synthetic');
        },
      );
      addTearDown(() {
        debugDefaultTargetPlatformOverride = null;
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        );
      });
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      androidTranslationDtmfInputFeedback();
      await tester.pump();
      expect(calls, isEmpty);
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      androidTranslationDtmfInputFeedback();
      await tester.pump();
      expect(calls.single.method, 'HapticFeedback.vibrate');
      expect(calls.single.arguments, 'HapticFeedbackType.selectionClick');
      debugDefaultTargetPlatformOverride = null;
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('enhanced keypad keeps hangup and every digit reachable at 2x', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final digits = <String>[];
    var hangups = 0;
    const state = TranslationCallView(
      phase: TranslationPhase.translating,
      dialPad: true,
      dtmfFeedbackAvailable: true,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.android),
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: TranslationCallPage(
            state: state,
            target: '合成翻译对象',
            controls: TranslationCallControls(
              state: state,
              onMute: () {},
              onSpeaker: () {},
              onPad: () {},
              onDigit: digits.add,
              onHangup: () => hangups++,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final hangup = find.byKey(const ValueKey('translation-control-挂断'));
    await tester.ensureVisible(hangup);
    await tester.tap(hangup);
    expect(hangups, 1);
    for (final digit in '123456789*0#'.split('')) {
      final key = find.byKey(ValueKey('translation-dtmf-$digit'));
      await tester.ensureVisible(key);
      await tester.tap(key);
      await tester.pumpAndSettle();
    }
    expect(digits.join(), '123456789*0#');
    await tester.ensureVisible(hangup);
    await tester.tap(hangup);
    expect(hangups, 2);
    expect(tester.takeException(), isNull);
  });

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('input history and pressed cancel are local on $platform', (
      tester,
    ) async {
      var state = const TranslationCallView(
        phase: TranslationPhase.translating,
        dialPad: true,
        dtmfFeedbackAvailable: true,
      );
      var sends = 0;
      Future<void> render({bool reduced = false}) => tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: platform),
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: reduced),
            child: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 320,
                  child: TranslationCallControls(
                    state: state,
                    onMute: () {},
                    onSpeaker: () {},
                    onPad: () {},
                    onDigit: (_) => sends++,
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
      final history = find.byKey(const ValueKey('translation-dtmf-history'));
      final key = find.byKey(const ValueKey('translation-dtmf-1'));
      if (platform == TargetPlatform.iOS) {
        expect(history, findsNothing);
        expect(find.byType(AnimatedScale), findsNothing);
        return;
      }
      expect(find.text('请输入按键'), findsOneWidget);
      final press = await tester.startGesture(tester.getCenter(key));
      await tester.pump();
      final scale = find.descendant(
        of: key,
        matching: find.byType(AnimatedScale),
      );
      expect(tester.widget<AnimatedScale>(scale).scale, .88);
      await tester.pump(const Duration(milliseconds: 45));
      final halfway = tester
          .widget<Transform>(
            find.descendant(of: key, matching: find.byType(Transform)),
          )
          .transform
          .storage[0];
      expect(halfway, greaterThan(.88));
      expect(halfway, lessThan(1));
      expect(sends, 0);
      await press.cancel();
      await tester.pumpAndSettle();
      expect(tester.widget<AnimatedScale>(scale).scale, 1);
      expect(sends, 0);
      for (var i = 0; i < 35; i++) {
        await tester.tap(key);
        await tester.pump();
      }
      expect(sends, 35);
      expect(tester.widget<Text>(history).data, '1' * 32);
      expect(state.dtmf, isEmpty);
      state = state.copy(controlsBusy: true);
      await render();
      await tester.tap(key);
      expect(sends, 35);
      state = state.copy(dialPad: false, controlsBusy: false);
      await render();
      state = state.copy(dialPad: true);
      await render(reduced: true);
      expect(find.text('请输入按键'), findsOneWidget);
      expect(find.byType(AnimatedScale), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
