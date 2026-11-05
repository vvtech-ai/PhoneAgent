import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/dialer/domain/system_dialer.dart';
import 'package:phone_agent/features/dialer/presentation/controller/dialer_controller.dart';
import 'package:phone_agent/features/dialer/presentation/pages/dialer_page.dart';
import 'package:phone_agent/features/dialer/presentation/widgets/native_dial_pad.dart';
import 'package:phone_agent/features/translation/presentation/widgets/native_translation_dial_summary.dart';

class _NoCalls implements SystemDialer {
  @override
  Future<SystemDialResult> open(String number) async {
    fail('Developer unlock must not open a phone call');
  }
}

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final unlock in [true, false]) {
      testWidgets('notice keeps history scroll boundary $platform/$unlock', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        var unlocked = 0;
        final controller = DialerController(
          _NoCalls(),
          onUnlockDeveloper: () => unlocked++,
        );
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: platform),
            home: StatefulBuilder(
              builder: (context, rebuild) => DialerPage(
                state: controller.state,
                translationEnabled: true,
                suggestions: controller.state.input.isEmpty
                    ? Column(
                        children: List.generate(
                          30,
                          (index) =>
                              SizedBox(height: 64, child: Text('合成历史 $index')),
                        ),
                      )
                    : const SizedBox.shrink(),
                configuration: NativeTranslationDialSummary(
                  model: 'Gemini Live',
                  languages: '中文 ⇄ 英文',
                  translationEnabled: true,
                  onModel: () {},
                  onLanguages: () {},
                ),
                onCountry: () {},
                onDigit: (digit) => rebuild(() => controller.digit(digit)),
                onDelete: () => rebuild(controller.delete),
                onClear: () => rebuild(controller.clear),
                onDial: () async {
                  await controller.dial();
                  rebuild(() {});
                },
                onClose: () {},
              ),
            ),
          ),
        );
        final pad = find.byType(NativeDialPad);
        final model = find.byKey(const Key('translation-model-open'));
        final call = find.byKey(const Key('dial-call'));
        final padPosition = tester.getTopLeft(pad);
        final modelPosition = tester.getTopLeft(model);
        final callPosition = tester.getTopLeft(call);

        Future<void> checkHistoryScroll() async {
          expect(
            find.ancestor(of: pad, matching: find.byType(Scrollable)),
            findsNothing,
          );
          final history = find.text('合成历史 0');
          final scroll = find.ancestor(
            of: history,
            matching: find.byType(Scrollable),
          );
          expect(scroll, findsOneWidget);
          final before = tester.getTopLeft(history);
          await tester.drag(scroll, const Offset(0, -120));
          await tester.pumpAndSettle();
          expect(tester.getTopLeft(history).dy, lessThan(before.dy));
          expect(tester.getTopLeft(pad), padPosition);
          expect(tester.getTopLeft(model), modelPosition);
          expect(tester.getTopLeft(call), callPosition);
          expect(tester.takeException(), isNull);
        }

        await checkHistoryScroll();
        if (unlock) {
          for (final digit in '20142014*#'.split('')) {
            await tester.tap(find.byKey(Key('dial-key-$digit')));
            await tester.pump();
          }
        }
        await tester.tap(call);
        await tester.pumpAndSettle();
        expect(unlocked, unlock ? 1 : 0);
        expect(
          find.text(unlock ? '已进入开发者模式' : '请输入正确的电话号码'),
          findsOneWidget,
        );
        await checkHistoryScroll();
        // Clear the notice through a regular digit/delete interaction.
        await tester.tap(find.byKey(const Key('dial-key-1')));
        await tester.pump();
        await tester.tap(find.byKey(const Key('dial-delete')));
        await tester.pump();
        expect(find.byKey(const Key('dial-message')), findsNothing);
        await checkHistoryScroll();
      });
    }
  }
}
