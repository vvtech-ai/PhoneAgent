import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/agent_protocol.dart';
import 'package:phone_agent/features/conversation/data/voice/preview_voice_input.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_controller.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_state.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_speech_controller.dart';
import 'package:phone_agent/features/conversation/presentation/pages/voice_input_preview_page.dart';
import 'conversation_speech_controller_test.dart' show SpeechFake;

class ReplyGateway implements AgentGateway {
  final events = StreamController<AgentEvent>();
  int cancellations = 0;
  @override
  AgentRun start(AgentCommand command) => AgentRun(events.stream, () {
    cancellations++;
  });
}

void main() {
  test(
    'production controller forwards reply and interrupts stream before ASR',
    () async {
      final gateway = ReplyGateway(), player = SpeechFake();
      final controller = ConversationController(
        entry: const ConversationEntry(sessionId: 'synthetic'),
        accountId: 'synthetic',
        gateway: gateway,
        history: PreviewVoiceInput(),
      );
      final speech = controller.speech = ConversationSpeechController(
        factory: (_, __) => player,
        enabled: () => controller.isOpen,
      );
      addTearDown(() {
        controller.dispose();
        gateway.events.close();
      });
      controller.send('测试');
      gateway.events.add(const AgentEvent(AgentEventKind.text, text: '当前回复。'));
      await Future<void>.delayed(Duration.zero);
      expect(player.sentences, ['当前回复。']);
      player.synthesizing = true;
      expect(controller.state.phase, ConversationPhase.sending);
      controller.interruptReplyForInput();
      expect(controller.state.phase, ConversationPhase.ready);
      expect(gateway.cancellations, 1);
      gateway.events.add(const AgentEvent(AgentEventKind.text, text: '不应播报。'));
      await Future<void>.delayed(Duration.zero);
      expect(player.sentences, ['当前回复。']);
      expect(speech.isActive, false);
    },
  );
  test(
    'keyboard mode remains VOICE; history and close never narrate history',
    () async {
      final player = SpeechFake(), ports = PreviewVoiceInput();
      final controller = ConversationController(
        entry: const ConversationEntry(sessionId: 'synthetic'),
        accountId: 'synthetic',
        gateway: ports,
        history: ports,
      );
      controller.speech = ConversationSpeechController(
        factory: (_, __) => player,
        enabled: () => controller.isOpen,
      );
      addTearDown(controller.dispose);
      await controller.restore();
      expect(player.sentences, isEmpty);
      controller.toggleInput();
      controller.send('键盘发送');
      await Future<void>.delayed(Duration.zero);
      expect(controller.state.voiceMode, false);
      expect(player.sentences.single, contains('MOCK：已收到输入'));
      controller.close();
      await Future<void>.delayed(Duration.zero);
      expect(controller.speech!.isActive, false);
    },
  );
  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets(
      '$width shared page reply playback, keyboard, failure and press',
      (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            // Business transitions are checked here; wave frames have their own suite.
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: child!,
            ),
            home: const VoiceInputPreviewPage(),
          ),
        );
        await tester.tap(find.byKey(const ValueKey('toggle-text')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('conversation-input')),
          '键盘播报',
        );
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('send-text')));
        await tester.pumpAndSettle();
        expect(find.text('AI 回复中...'), findsWidgets);
        await tester.tap(find.text('模拟播完'));
        await tester.pumpAndSettle();
        expect(find.text('AI 回复中...'), findsNothing);
        await tester.enterText(
          find.byKey(const ValueKey('conversation-input')),
          '失败测试',
        );
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('send-text')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('模拟播放失败'));
        await tester.pumpAndSettle();
        expect(find.text('播报失败，可继续文字交互'), findsWidgets);
        expect(find.text('失败测试'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('toggle-voice')));
        await tester.pumpAndSettle();
        final hold = find.byKey(const ValueKey('conversation-voice-button'));
        final gesture = await tester.startGesture(tester.getCenter(hold));
        await tester.pump(const Duration(milliseconds: 400));
        await gesture.up();
        await tester.pump(const Duration(seconds: 2));
        await tester.pumpAndSettle();
        expect(find.text('AI 回复中...'), findsWidgets);
        expect(hold, findsNothing, reason: 'TTS uses the original stop control');
        await tester.tap(find.byKey(const ValueKey('stop-current-processing')));
        await tester.pumpAndSettle();
        expect(find.text('AI 回复中...'), findsNothing);
        final interrupt = await tester.startGesture(tester.getCenter(hold));
        await tester.pump();
        expect(find.text('正在聆听...'), findsWidgets);
        await interrupt.cancel();
        await tester.pumpAndSettle();
        expect(find.text('AI 回复中...'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );
  }
}
