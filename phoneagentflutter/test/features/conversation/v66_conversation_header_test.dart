import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_state.dart';
import 'package:phone_agent/features/conversation/presentation/controller/voice_input_state.dart';
import 'package:phone_agent/features/conversation/presentation/pages/conversation_page.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/native_conversation_wave.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/voice_composer_binding.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('$platform five-line draft fits a short keyboard viewport', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: platform),
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(
                textScaler: TextScaler.linear(2),
                viewInsets: EdgeInsets.only(bottom: 300),
              ),
              child: SizedBox(
                height: 268,
                child: ConversationPage(
                  state: const ConversationState(
                    entry: ConversationEntry(sessionId: 'short-draft'),
                    voiceMode: false,
                  ),
                  modelName: 'QwenOmniPlus',
                  onClose: () {},
                  onToggle: () {},
                  onSend: (_) => false,
                  onChoose: (_, _) => false,
                  onRetry: () {},
                  onNotice: (_) {},
                  onModels: () {},
                ),
              ),
            ),
          ),
        ),
      );
      final input = find.byKey(const ValueKey('conversation-input'));
      await tester.enterText(input, '第一行\n第二行\n第三行\n第四行\n第五行\n第六行');
      await tester.pumpAndSettle();
      expect(tester.getRect(input).bottom, lessThanOrEqualTo(268));
      expect(
        find.byKey(const ValueKey('task-input-expand')).hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
    testWidgets('$platform status, seven bars and speaker share one row', (
      tester,
    ) async {
      var toggles = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: platform),
          home: Scaffold(
            body: ConversationPage(
              state: const ConversationState(
                entry: ConversationEntry(sessionId: 'header-test'),
              ),
              modelName: '测试模型',
              onClose: () {},
              onToggle: () {},
              onSend: (_) => false,
              onChoose: (_, _) => false,
              onRetry: () {},
              onNotice: (_) {},
              onModels: () {},
              voice: VoiceComposerBinding(
                state: const VoiceInputState(),
                guideHint: '按住说话',
                onPress: () {},
                onRelease: () {},
                onCancel: () {},
                onToggleSpeech: () {
                  toggles++;
                },
              ),
            ),
          ),
        ),
      );
      final speaker = find.byKey(const ValueKey('conversation-speech-toggle'));
      expect(tester.widget<IconButton>(speaker).tooltip, isNull);
      expect(find.bySemanticsLabel('关闭 AI 发声'), findsOneWidget);
      final close = find.byKey(const ValueKey('close-conversation'));
      final wave = find.byType(NativeConversationWave);
      final status = find.text('语音待命中...');
      final guide = find.text('按住说话');
      final mic = find.byKey(const ValueKey('conversation-voice-button'));
      expect(guide, findsOneWidget);
      expect(
        tester.getCenter(guide).dy,
        greaterThan(tester.getCenter(speaker).dy + 100),
      );
      expect(tester.getCenter(guide).dy, lessThan(tester.getCenter(mic).dy));
      expect(
        tester.getCenter(mic).dy - tester.getCenter(guide).dy,
        lessThan(120),
      );
      expect(find.text('语音识别中'), findsNothing);
      expect(
        tester.getCenter(speaker).dy,
        closeTo(tester.getCenter(status).dy, 1),
      );
      expect(
        tester.getCenter(speaker).dx,
        closeTo(tester.getCenter(close).dx, .01),
      );
      expect(
        tester.getCenter(wave).dy,
        closeTo(tester.getCenter(status).dy, 1),
      );
      expect(tester.getSize(wave), const Size(26, 27));
      expect(
        find.byKey(const ValueKey('conversation-wave-bar-6')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('conversation-wave-bar-7')),
        findsNothing,
      );
      expect(
        find.descendant(of: close, matching: find.byType(DecoratedBox)),
        findsNothing,
      );
      await tester.tap(speaker);
      expect(toggles, 1);
    });
  }
}
