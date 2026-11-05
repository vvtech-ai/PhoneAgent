import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/conversation_messages.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_state.dart';
import 'package:phone_agent/features/conversation/presentation/controller/voice_input_state.dart';
import 'package:phone_agent/features/conversation/presentation/pages/conversation_page.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/native_conversation_wave.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/voice_composer_binding.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final mode in [
      NativeConversationWaveMode.listening,
      NativeConversationWaveMode.speaking,
    ]) {
      testWidgets('$platform $mode animates, reduces and releases', (
        tester,
      ) async {
        var current = mode;
        var reduce = false;
        late StateSetter change;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: platform),
            home: StatefulBuilder(
              builder: (context, setState) {
                change = setState;
                return MediaQuery(
                  data: MediaQueryData(disableAnimations: reduce),
                  child: Center(child: NativeConversationWave(mode: current)),
                );
              },
            ),
          ),
        );
        expect(
          tester.getSize(find.byType(NativeConversationWave)),
          const Size(26, 27),
        );
        expect(
          _color(tester),
          mode == NativeConversationWaveMode.speaking
              ? const Color(0xFF2EAD5B)
              : const Color(0xFF0A84FF),
        );
        final initial = _scale(tester);
        await tester.pump(const Duration(milliseconds: 350));
        expect(_scale(tester), isNot(closeTo(initial, .001)));
        expect(_scale(tester), greaterThanOrEqualTo(.78));
        expect(_scale(tester), lessThanOrEqualTo(1.28));
        change(() => reduce = true);
        await tester.pump();
        expect(_scale(tester), 1);
        await tester.pump(const Duration(seconds: 2));
        expect(tester.binding.transientCallbackCount, 0);
        change(() {
          reduce = false;
          current = NativeConversationWaveMode.standby;
        });
        await tester.pump();
        expect(_scale(tester), 1);
        expect(_color(tester), const Color(0xFF0A84FF));
        change(() => current = mode);
        await tester.pump();
        // Dispose before the delayed second phase starts.
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 2));
        expect(tester.binding.transientCallbackCount, 0);
        expect(tester.takeException(), isNull);
      });
    }
    testWidgets('$platform existing voice state alone controls wave', (
      tester,
    ) async {
      var phase = VoiceInputPhase.idle;
      var replying = false;
      var thinking = false;
      late StateSetter change;
      var actions = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: platform),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                change = setState;
                return ConversationPage(
                  state: ConversationState(
                    entry: const ConversationEntry(sessionId: 'synthetic-wave'),
                    phase: thinking
                        ? ConversationPhase.sending
                        : ConversationPhase.ready,
                    activity: thinking ? '正在思考…' : '',
                    messages: const [
                      ConversationMessage(
                        id: 'history',
                        role: MessageRole.assistant,
                        text: '合成已有消息',
                      ),
                    ],
                  ),
                  voice: VoiceComposerBinding(
                    state: VoiceInputState(phase: phase),
                    canInterruptReply: replying,
                    onPress: () => actions++,
                    onRelease: () => actions++,
                    onCancel: () => actions++,
                  ),
                  modelName: 'QwenOmniPlus',
                  onClose: () {},
                  onToggle: () {},
                  onSend: (_) {
                    actions++;
                    return false;
                  },
                  onChoose: (_, _) => false,
                  onRetry: () {},
                  onNotice: (_) {},
                  onModels: () {},
                );
              },
            ),
          ),
        ),
      );
      final wave = find.byType(NativeConversationWave);
      expect(
        tester.widget<NativeConversationWave>(wave).mode,
        NativeConversationWaveMode.standby,
      );
      change(() {
        replying = true;
        thinking = true;
      });
      await tester.pump();
      expect(
        tester.widget<NativeConversationWave>(wave).mode,
        NativeConversationWaveMode.speaking,
      );
      change(() {
        replying = false;
        phase = VoiceInputPhase.recording;
      });
      await tester.pump();
      expect(
        tester.widget<NativeConversationWave>(wave).mode,
        NativeConversationWaveMode.listening,
      );
      change(() {
        phase = VoiceInputPhase.idle;
        replying = false;
      });
      await tester.pump();
      expect(
        tester.widget<NativeConversationWave>(wave).mode,
        NativeConversationWaveMode.standby,
      );
      change(() => thinking = false);
      await tester.pump();
      expect(
        tester.widget<NativeConversationWave>(wave).mode,
        NativeConversationWaveMode.standby,
      );
      expect(actions, 0);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 2));
      expect(tester.takeException(), isNull);
    });
  }
}

Finder get _bar => find.byKey(const ValueKey('conversation-wave-bar-0'));
double _scale(WidgetTester tester) => tester
    .widget<Transform>(
      find.ancestor(of: _bar, matching: find.byType(Transform)).first,
    )
    .transform
    .storage[5];
Color _color(WidgetTester tester) =>
    (tester.widget<Container>(_bar).decoration! as BoxDecoration).color!;
