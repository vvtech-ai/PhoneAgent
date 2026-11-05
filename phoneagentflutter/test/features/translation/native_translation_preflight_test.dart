import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/translation/domain/translation_call_view.dart';
import 'package:phone_agent/features/translation/presentation/pages/translation_call_page.dart';
import 'package:phone_agent/features/translation/presentation/widgets/translation_call_controls.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'preflight native style, cancel and short screen $platform/$scale',
        (tester) async {
          tester.view.physicalSize = const Size(320, 480);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          var cancels = 0;
          Future<void> render(bool stopping) => tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(
                platform: platform,
                colorSchemeSeed: Colors.green,
              ),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(scale),
                  disableAnimations: true,
                ),
                child: child!,
              ),
              home: TranslationCallPage(
                state: TranslationCallView(stopping: stopping),
                target: '合成号码',
                controls: TranslationCallControls(
                  state: TranslationCallView(stopping: stopping),
                  onMute: () {},
                  onPad: () {},
                  onSpeaker: () {},
                  onDigit: (_) {},
                  onHangup: () => cancels++,
                ),
              ),
            ),
          );
          await render(false);
          expect(find.byType(Card), findsNothing);
          expect(find.byType(CircularProgressIndicator), findsNothing);
          expect(find.text('合成号码'), findsOneWidget);
          expect(find.text('正在检测通话环境'), findsOneWidget);
          expect(find.text('00:00'), findsOneWidget);
          expect(find.text('取消通话准备'), findsNothing);
          expect(tester.takeException(), isNull);
          await tester.ensureVisible(find.bySemanticsLabel('挂断'));
          await tester.pumpAndSettle();
          await tester.tap(find.bySemanticsLabel('挂断'));
          expect(cancels, 1);
          await render(true);
          await tester.ensureVisible(find.bySemanticsLabel('挂断'));
          await tester.pumpAndSettle();
          await tester.tap(find.bySemanticsLabel('挂断'));
          expect(cancels, 1);
          expect(find.byType(TranslationCallControls), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
