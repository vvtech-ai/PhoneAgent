import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/calls/data/preview_call_flow.dart';
import 'package:phone_agent/features/calls/presentation/pages/call_flow_preview_page.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_speech_controller.dart';
import '../../calls/conversation_call_flow_test.dart' show conversation, launch;
import 'conversation_speech_controller_test.dart' show SpeechFake;

void main() {
  testWidgets(
    'production single observer synchronizes durable reply, returns then narrates once',
    (tester) async {
      final ports = PreviewCallFlow(
        CallFlowScenario.single,
        narrateResults: true,
      );
      final controller = conversation(ports);
      final player = SpeechFake();
      final speech = controller.speech = ConversationSpeechController(
        enabled: () =>
            controller.isOpen && !controller.calls!.snapshot.showCall,
        factory: (_, __) => player,
      );
      final remove = controller.calls!.addListener((call) {
        if (call.showCall) {
          speech.pauseForCall();
        } else {
          speech.resumeResult();
        }
      });
      addTearDown(() {
        remove();
        controller.dispose();
      });
      await launch(tester, controller);
      ports.ended = true;
      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pump();
      expect(controller.calls!.snapshot.showCall, false);
      expect(player.sentences, ['请确认以上任务内容，是否现在拨打？']);
      ports.outcomeReady = true;
      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pump();
      expect(controller.calls!.snapshot.showCall, false);
      expect(player.sentences, ['请确认以上任务内容，是否现在拨打？', 'MOCK：单路任务已完成，已返回对话。']);
      expect(
        controller.state.messages.any((m) => m.text == player.sentences.last),
        true,
      );
      await controller.restore();
      expect(player.sentences.length, 2);
      expect(ports.commands.length, 2);
      expect(ports.hangups, 0);
    },
  );
  testWidgets(
    'production batch gap reconciliation and repeated terminal narrate only durable reply',
    (tester) async {
      final ports = PreviewCallFlow(
        CallFlowScenario.batch,
        narrateResults: true,
      );
      final controller = conversation(ports), player = SpeechFake();
      controller.speech = ConversationSpeechController(
        enabled: () => controller.isOpen,
        factory: (_, __) => player,
      );
      addTearDown(controller.dispose);
      await launch(tester, controller);
      expect(player.sentences, ['请确认以上任务内容，是否现在拨打？', 'MOCK：两路任务均已完成。']);
      expect(controller.calls!.snapshot.showCall, false);
      expect(ports.polls, 0);
      await controller.restore();
      expect(player.sentences.length, 2);
    },
  );
  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets('$width shared call page result playback then silent history', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        const MaterialApp(
          home: CallFlowPreviewPage(scenario: CallFlowScenario.single),
        ),
      );
      await tester.tap(find.text('发送合成需求'));
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump();
      await tester.tap(find.text('确认合成拨打'));
      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pump();
      await tester.tap(find.text('合成结果到达'));
      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pumpAndSettle();
      expect(find.text('MOCK：单路任务已完成，已返回对话。'), findsOneWidget);
      expect(find.textContaining('合成播报：正在播报'), findsOneWidget);
      await tester.tap(find.text('模拟播完'));
      await tester.pumpAndSettle();
      expect(find.textContaining('合成播报：空闲'), findsOneWidget);
      await tester.tap(find.text('恢复合成历史'));
      await tester.pumpAndSettle();
      expect(find.textContaining('合成播报：正在播报'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  }
}
