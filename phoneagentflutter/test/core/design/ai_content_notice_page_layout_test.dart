import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/calls/domain/call_session.dart';
import 'package:phone_agent/features/calls/presentation/controller/call_presentation.dart';
import 'package:phone_agent/features/calls/presentation/controller/call_session_state.dart';
import 'package:phone_agent/features/calls/presentation/pages/call_session_page.dart';
import 'package:phone_agent/features/translation/domain/translation_call_view.dart';
import 'package:phone_agent/features/translation/presentation/pages/translation_call_page.dart';
import 'package:phone_agent/features/translation/presentation/widgets/translation_call_controls.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final sample in [
      (const Size(320, 480), 2.0, 34.0, 3.0),
      (const Size(360, 640), 1.3, 0.0, 1.0),
      (const Size(390, 844), 1.0, 34.0, 3.0),
      (const Size(430, 932), 2.0, 0.0, 2.0),
    ]) {
      for (final translation in [false, true]) {
        testWidgets(
          '$platform size=${sample.$1} translation=$translation fixed footer',
          (tester) async {
            tester.view.devicePixelRatio = sample.$4;
            tester.view.physicalSize = sample.$1 * sample.$4;
            tester.view.padding = FakeViewPadding(
              bottom: sample.$3 * sample.$4,
            );
            tester.view.viewPadding = FakeViewPadding(
              bottom: sample.$3 * sample.$4,
            );
            addTearDown(tester.view.reset);
            var hangups = 0;
            Future<void> render({
              bool pad = false,
              bool stopping = false,
              bool ended = false,
            }) {
              final state = TranslationCallView(
                dialPad: pad,
                stopping: stopping,
                phase: ended
                    ? TranslationPhase.ended
                    : TranslationPhase.connected,
              );
              return tester.pumpWidget(
                MaterialApp(
                  theme: ThemeData(platform: platform),
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: TextScaler.linear(sample.$2)),
                    child: child!,
                  ),
                  home: translation
                      ? TranslationCallPage(
                          state: state,
                          target: '测试机',
                          controls: TranslationCallControls(
                            state: state,
                            onMute: () {},
                            onSpeaker: () {},
                            onPad: () {},
                            onDigit: (_) {},
                            onHangup: () => hangups++,
                          ),
                        )
                      : Scaffold(
                          body: CallSessionPage(
                            state: CallSessionState(
                              target: CallSessionTarget(callId: 'call'),
                              phase: ended
                                  ? CallSessionPhase.ended
                                  : CallSessionPhase.observing,
                              hangingUp: stopping,
                            ),
                            monitor: const CallMonitorView(),
                            modelName: '测试模型',
                            targetName: '测试机',
                            seconds: 0,
                            onMonitor: () {},
                            onSource: () {},
                            onHangup: () => hangups++,
                          ),
                        ),
                ),
              );
            }

            void verify() {
              final finder = find.text('内容由AI生成');
              expect(finder, findsOneWidget);
              final rect = tester.getRect(finder);
              expect(rect.center.dx, closeTo(sample.$1.width / 2, .1));
              expect(
                rect.bottom,
                closeTo(
                  sample.$1.height -
                      sample.$3 -
                      (platform == TargetPlatform.iOS && sample.$3 > 0
                          ? 10
                          : 20),
                  .1,
                ),
              );
              final label = find.text('挂断中').evaluate().isNotEmpty
                  ? find.text('挂断中')
                  : find.text('挂断');
              final originalGap = translation ? 7.0 : 8.0;
              expect(
                rect.top - tester.getRect(label).bottom,
                closeTo(
                  originalGap +
                      (platform == TargetPlatform.iOS && sample.$3 > 0
                          ? 10
                          : 0),
                  .1,
                ),
              );
              // The extra upper gap and reduced lower gap cancel out: buttons stay put.
              expect(
                tester.getRect(label).bottom,
                closeTo(
                  sample.$1.height - sample.$3 - 20 - rect.height - originalGap,
                  .1,
                ),
              );
              final text = tester.widget<Text>(finder);
              expect(text.style!.fontSize, 11);
              expect(
                text.style!.color,
                const Color.fromRGBO(255, 255, 255, .34),
              );
              expect(
                tester
                    .renderObject<RenderParagraph>(finder)
                    .textScaler
                    .scale(11),
                11,
              );
              expect(
                find.ancestor(of: finder, matching: find.byType(Opacity)),
                findsNothing,
              );
              expect(tester.takeException(), isNull);
            }

            await render();
            await tester.pumpAndSettle();
            verify();
            if (translation) {
              await render(pad: true);
              await tester.pumpAndSettle();
              verify();
              final scroll = find.ancestor(
                of: find.text('内容由AI生成'),
                matching: find.byType(SingleChildScrollView),
              );
              expect(
                scroll,
                findsNothing,
                reason: 'the footer must not scroll with the dial pad',
              );
            }
            await render(stopping: true);
            await tester.pumpAndSettle();
            verify();
            expect(hangups, 0);
            await render(ended: true);
            await tester.pumpAndSettle();
            verify();
            expect(hangups, 0);
          },
        );
      }
    }
  }
}
