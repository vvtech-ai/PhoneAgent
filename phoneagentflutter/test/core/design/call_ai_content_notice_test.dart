import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/design/ai_content_notice.dart';
import 'package:phone_agent/features/calls/domain/call_session.dart';
import 'package:phone_agent/features/calls/presentation/controller/call_presentation.dart';
import 'package:phone_agent/features/calls/presentation/controller/call_session_state.dart';
import 'package:phone_agent/features/calls/presentation/widgets/call_controls.dart';
import 'package:phone_agent/features/translation/domain/translation_call_view.dart';
import 'package:phone_agent/features/translation/presentation/widgets/translation_call_controls.dart';

void main() {
  testWidgets('notice wraps completely without shrinking or adding an action', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var disposed = false;
    addTearDown(() {
      if (!disposed) semantics.dispose();
    });
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: SizedBox(width: 40, child: AiContentNotice.dark()),
            ),
          ),
        ),
      ),
    );
    final notice = find.text('内容由AI生成');
    final paragraph = tester.renderObject<RenderParagraph>(notice);
    final boxes = paragraph.getBoxesForSelection(
      const TextSelection(baseOffset: 0, extentOffset: 7),
    );
    expect(boxes.map((box) => box.top).toSet().length, greaterThan(1));
    expect(paragraph.didExceedMaxLines, isFalse);
    expect(paragraph.textScaler.scale(11), 11);
    expect(tester.getSize(notice).width, lessThanOrEqualTo(40));
    expect(tester.getSemantics(notice).getSemanticsData().label, '内容由AI生成');
    expect(
      tester
          .getSemantics(notice)
          .getSemanticsData()
          .hasAction(SemanticsAction.tap),
      isFalse,
    );
    expect(tester.takeException(), isNull);
    semantics.dispose();
    disposed = true;
  });
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final translation in [true, false]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets(
          '$platform translation=$translation scale=$scale full notice',
          (tester) async {
            tester.view.physicalSize = const Size(320, 700);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            var hangups = 0;
            Future<void> render(bool stopping) => tester.pumpWidget(
              MaterialApp(
                theme: ThemeData(platform: platform),
                home: MediaQuery(
                  data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                  child: Scaffold(
                    body: Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        child: translation
                            ? TranslationCallControls(
                                state: TranslationCallView(stopping: stopping),
                                onMute: () {},
                                onSpeaker: () {},
                                onPad: () {},
                                onDigit: (_) {},
                                onHangup: () => hangups++,
                              )
                            : CallControls(
                                call: CallSessionState(
                                  target: CallSessionTarget(callId: 'call'),
                                  phase: CallSessionPhase.observing,
                                  hangingUp: stopping,
                                ),
                                monitor: const CallMonitorView(),
                                onMonitor: () {},
                                onSource: () {},
                                onHangup: () => hangups++,
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            );
            await render(false);
            final notice = find.text('内容由AI生成');
            expect(notice, findsOneWidget);
            final label = find.text('挂断');
            final noticeText = tester.widget<Text>(notice);
            final labelText = tester.widget<Text>(label);
            expect(
              noticeText.style,
              const TextStyle(
                fontSize: 11,
                color: Color.fromRGBO(255, 255, 255, .34),
                fontWeight: FontWeight.w400,
                fontStyle: FontStyle.normal,
              ),
            );
            expect(labelText.style!.fontSize, translation ? 13 : 12);
            final labelParagraph = tester.renderObject<RenderParagraph>(label);
            expect(
              labelParagraph.textScaler.scale(labelText.style!.fontSize!),
              labelText.style!.fontSize! * scale,
            );
            expect(noticeText.textAlign, TextAlign.center);
            expect(noticeText.textScaler, TextScaler.noScaling);
            expect(noticeText.maxLines, isNull);
            expect(noticeText.overflow, isNot(TextOverflow.ellipsis));
            final paragraph = tester.renderObject<RenderParagraph>(notice);
            expect(paragraph.didExceedMaxLines, isFalse);
            final noticeRect = tester.getRect(notice);
            expect(noticeRect.left, greaterThanOrEqualTo(18));
            expect(noticeRect.right, lessThanOrEqualTo(302));
            expect(noticeRect.bottom, lessThanOrEqualTo(700));
            final button = find.byKey(
              ValueKey(translation ? 'translation-control-挂断' : 'call-挂断'),
            );
            final originalGap =
                tester.getTopLeft(label).dy - tester.getBottomLeft(button).dy;
            expect(originalGap, closeTo(translation ? 7 : 8, .01));
            expect(
              noticeRect.top - tester.getBottomLeft(label).dy,
              closeTo(originalGap, .01),
            );
            await tester.tap(button);
            expect(hangups, 1);
            await render(true);
            expect(notice, findsOneWidget);
            expect(
              tester.widget<Text>(notice).style!.color,
              const Color.fromRGBO(255, 255, 255, .34),
            );
            expect(
              find.ancestor(of: notice, matching: find.byType(Opacity)),
              findsNothing,
            );
            await tester.tap(button);
            expect(hangups, 1);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
}
