import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/calls/domain/call_session.dart';
import 'package:phone_agent/features/calls/domain/call_transcript.dart';
import 'package:phone_agent/features/calls/presentation/controller/call_presentation.dart';
import 'package:phone_agent/features/calls/presentation/controller/call_session_state.dart';
import 'package:phone_agent/features/calls/presentation/pages/call_session_page.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('single call terminal fits short large text $platform', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 390);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      var actions = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: platform),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: CallSessionPage(
              state: CallSessionState(
                target: CallSessionTarget(taskId: 'task', callId: 'call'),
                phase: CallSessionPhase.awaitingOutcome,
                transcript: CallTranscript(
                  lines: const [
                    CallTranscriptLine(
                      CallSpeaker.assistant,
                      '合成转写内容用于验证短屏滚动。',
                    ),
                  ],
                ),
              ),
              monitor: const CallMonitorView(),
              modelName: 'QwenOmniPlus',
              seconds: 10,
              targetName: '合成联系人',
              phoneNumber: '+12025550101',
              onMonitor: () => actions++,
              onHangup: () => actions++,
              onSource: () => actions++,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final region = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
        find
            .descendant(
              of: find.byType(CallSessionPage),
              matching: find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
            )
            .first,
      );
      expect(region.value.statusBarIconBrightness, Brightness.light);
      expect(region.value.statusBarBrightness, Brightness.dark);
      for (final label in ['监听', '挂断', '听筒']) {
        final opacity = tester.widget<Opacity>(
          find
              .ancestor(of: find.text(label), matching: find.byType(Opacity))
              .first,
        );
        expect(opacity.opacity, .38);
      }
      await tester.tap(
        find.byKey(const ValueKey('call-挂断')),
        warnIfMissed: false,
      );
      expect(actions, 0);
      await tester.scrollUntilVisible(
        find.text('合成联系人'),
        -150,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
