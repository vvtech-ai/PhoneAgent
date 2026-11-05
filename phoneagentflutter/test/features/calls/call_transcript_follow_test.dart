import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/calls/domain/call_session.dart';
import 'package:phone_agent/features/calls/domain/call_transcript.dart';
import 'package:phone_agent/features/calls/presentation/controller/call_presentation.dart';
import 'package:phone_agent/features/calls/presentation/controller/call_session_state.dart';
import 'package:phone_agent/features/calls/presentation/pages/call_session_page.dart';

Future<void> render(
  WidgetTester tester,
  CallTranscript transcript,
  TargetPlatform platform, {
  int seconds = 1,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(platform: platform),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: const TextScaler.linear(1.6)),
        child: child!,
      ),
      home: Scaffold(
        body: CallSessionPage(
          state: CallSessionState(
            target: CallSessionTarget(taskId: 'synthetic', callId: 'synthetic'),
            phase: CallSessionPhase.observing,
            snapshot: const CallSessionSnapshot(
              callId: 'synthetic',
              taskId: 'synthetic',
              callState: 'CONNECTED',
              launchReady: true,
            ),
            transcript: transcript,
          ),
          monitor: const CallMonitorView(),
          modelName: '合成模型',
          seconds: seconds,
          onMonitor: () {},
          onHangup: () {},
          onSource: () {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('$platform follows live subtitles without polling source', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      var transcript = CallTranscript();
      await render(tester, transcript, platform);
      final scrollable = find.descendant(
        of: find.byType(CallSessionPage),
        matching: find.byType(Scrollable),
      );
      ScrollPosition position() =>
          tester.state<ScrollableState>(scrollable).position;
      for (var index = 1; index <= 12; index++) {
        final message = index.isEven
            ? '对方：好的'
            : '助手：第$index句，请确认预约时间和人数。${'这是合成的连续长字幕。' * (index % 3 + 1)}';
        transcript = transcript.live('synthetic', index, message);
        expect(transcript.source, isEmpty);
        await render(tester, transcript, platform);
        expect(
          position().extentAfter,
          lessThan(1),
          reason: 'new line $index must be visible',
        );
      }
      expect(transcript.lines, hasLength(12));
      expect(position().maxScrollExtent, greaterThan(100));
      position().jumpTo(0);
      await tester.pumpAndSettle();
      await render(tester, transcript, platform, seconds: 20);
      expect(position().pixels, 0);
      final sameVisible = transcript.merge(
        'assistant: ${transcript.lines.first.text}',
      );
      await render(tester, sameVisible, platform, seconds: 21);
      expect(position().pixels, 0);
      expect(sameVisible.lines.length, transcript.lines.length);
      final nextLive = sameVisible.live('synthetic', 13, '对方：好的');
      expect(nextLive.source, sameVisible.source);
      await render(tester, nextLive, platform, seconds: 22);
      expect(nextLive.lines.length, 13);
      expect(position().extentAfter, lessThan(1));
      expect(tester.takeException(), isNull);
    });
  }
}
