import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/calls/domain/call_session.dart';
import 'package:phone_agent/features/calls/domain/call_transcript.dart';
import 'package:phone_agent/features/calls/presentation/controller/call_presentation.dart';
import 'package:phone_agent/features/calls/presentation/controller/call_session_state.dart';
import 'package:phone_agent/features/calls/presentation/pages/call_session_page.dart';

void main() {
  testWidgets(
    'SSE captions follow before polling while timer refresh stays put',
    (tester) async {
      var transcript = CallTranscript().merge(
        List.generate(20, (i) => 'AI: 第 $i 条通话转写').join('\n'),
      );
      Future<void> show({int seconds = 1}) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CallSessionPage(
                state: CallSessionState(
                  target: CallSessionTarget(
                    taskId: 'synthetic',
                    callId: 'call',
                  ),
                  transcript: transcript,
                  snapshot: const CallSessionSnapshot(
                    callId: 'call',
                    taskId: 'synthetic',
                    callState: 'CONNECTED',
                  ),
                ),
                monitor: const CallMonitorView(),
                modelName: '通话模型',
                seconds: seconds,
                onMonitor: () {},
                onHangup: () {},
                onSource: () {},
              ),
            ),
          ),
        );
        await tester.pump();
      }

      ScrollPosition position() =>
          tester.state<ScrollableState>(find.byType(Scrollable).first).position;
      await show();
      expect(position().pixels, closeTo(position().maxScrollExtent, 1));
      await tester.drag(find.byType(ListView), const Offset(0, 240));
      await tester.pumpAndSettle();
      final browsing = position().pixels;
      await show(seconds: 2);
      expect(position().pixels, browsing);
      final oldSource = transcript.source;
      transcript = transcript.live('attempt', 21, '对方: 最新实时回答');
      expect(transcript.source, oldSource);
      await show(seconds: 3);
      expect(position().pixels, closeTo(position().maxScrollExtent, 1));
      expect(find.text('最新实时回答').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
