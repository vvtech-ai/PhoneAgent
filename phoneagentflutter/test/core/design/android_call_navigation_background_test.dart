import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/design/native_system_chrome.dart';
import 'package:phone_agent/features/calls/domain/call_session.dart';
import 'package:phone_agent/features/calls/presentation/controller/call_presentation.dart';
import 'package:phone_agent/features/calls/presentation/controller/call_session_state.dart';
import 'package:phone_agent/features/calls/presentation/pages/call_session_page.dart';
import 'package:phone_agent/features/translation/domain/translation_call_view.dart';
import 'package:phone_agent/features/translation/presentation/pages/translation_call_page.dart';
import 'package:phone_agent/features/translation/presentation/widgets/translation_call_controls.dart';

Widget callPage(bool translation, {VoidCallback? onHangup}) {
  if (translation) {
    const state = TranslationCallView(phase: TranslationPhase.connected);
    return TranslationCallPage(
      state: state,
      target: '合成通话',
      controls: TranslationCallControls(
        state: state,
        onMute: () {},
        onSpeaker: () {},
        onPad: () {},
        onDigit: (_) {},
        onHangup: onHangup ?? () {},
      ),
    );
  }
  return CallSessionPage(
    state: CallSessionState(
      target: CallSessionTarget(taskId: 'task', callId: 'call'),
      phase: CallSessionPhase.observing,
      snapshot: const CallSessionSnapshot(
        taskId: 'task',
        callId: 'call',
        callState: 'CONNECTED',
      ),
    ),
    monitor: const CallMonitorView(),
    modelName: '合成模型',
    targetName: '合成通话',
    seconds: 1,
    onMonitor: () {},
    onSource: () {},
    onHangup: onHangup ?? () {},
  );
}

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final translation in [false, true]) {
      testWidgets(
        '$platform translation=$translation navigation backing and safe footer',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = const Size(390, 844);
          tester.view.padding = const FakeViewPadding(bottom: 24);
          addTearDown(tester.view.reset);
          var hangups = 0;
          final page = callPage(translation, onHangup: () => hangups++);
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(platform: platform),
              home: AnnotatedRegion<SystemUiOverlayStyle>(
                value: NativeSystemChrome.light,
                child: Scaffold(backgroundColor: Colors.white, body: page),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final localScaffolds = find.descendant(
            of: find.byType(page.runtimeType),
            matching: find.byType(Scaffold),
          );
          if (platform == TargetPlatform.android) {
            expect(localScaffolds, findsOneWidget);
            expect(
              tester.widget<Scaffold>(localScaffolds).backgroundColor,
              translation ? const Color(0xFF1A2C52) : const Color(0xFF0B0D12),
            );
          } else {
            expect(localScaffolds, translation ? findsOneWidget : findsNothing);
            if (translation) {
              expect(
                tester.widget<Scaffold>(localScaffolds).backgroundColor,
                isNull,
              );
            }
          }
          final notice = tester.getRect(find.text('内容由AI生成'));
          expect(notice.bottom, closeTo(844 - 24 - 20, .1));
          final style = SystemChrome.latestStyle!;
          expect(style.systemNavigationBarColor, Colors.transparent);
          expect(style.systemNavigationBarIconBrightness, Brightness.light);
          expect(hangups, 0);
          final button = translation
              ? find.byKey(const ValueKey('translation-control-挂断'))
              : find.byKey(const ValueKey('call-挂断'));
          await tester.tap(button);
          await tester.pump();
          expect(hangups, 1);
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
        },
      );
    }
  }
}
