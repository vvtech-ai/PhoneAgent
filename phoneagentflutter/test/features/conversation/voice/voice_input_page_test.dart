import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/agent_context_providers.dart';
import 'package:phone_agent/app/app_providers.dart';
import 'package:phone_agent/app/conversation_providers.dart';
import 'package:phone_agent/app/conversation_voice_providers.dart';
import 'package:phone_agent/core/config/app_config.dart';
import 'package:phone_agent/features/conversation/data/voice/preview_voice_input.dart';
import 'package:phone_agent/features/conversation/domain/voice/voice_gateway_event.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_controller.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_state.dart';
import 'package:phone_agent/features/conversation/presentation/controller/voice_input_state.dart';
import 'package:phone_agent/features/conversation/presentation/pages/voice_input_preview_page.dart';
import 'package:phone_agent/features/conversation/presentation/pages/conversation_page.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/conversation_voice_host.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/voice_hold_button.dart';
import 'voice_input_fake.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/native_conversation_text_bubble.dart';

void main() {
  final button = find.byKey(const ValueKey('conversation-voice-button'));
  Future<void> mount(
    WidgetTester tester, {
    Size size = const Size(390, 844),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    // This suite verifies business state; decorative loops are tested separately.
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: const VoiceInputPreviewPage(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'pointer down immediate; hold partial; release submits; then text',
    (tester) async {
      await mount(tester);
      final gesture = await tester.startGesture(tester.getCenter(button));
      await tester.pump();
      expect(find.text('正在聆听...'), findsWidgets);
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const ValueKey('voice-transcript')), findsOneWidget);
      final preview = tester.widget<NativeConversationTextBubble>(
        find.byKey(const ValueKey('voice-transcript')),
      );
      expect(preview.user, isTrue);
      expect(preview.copyEnabled, isFalse);
      await gesture.up();
      await tester.pump();
      expect(find.text('正在聆听...'), findsWidgets);
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.textContaining('MOCK：已收到输入'), findsOneWidget);
      // Synthetic PCM drains only through the preview's explicit output control.
      await tester.tap(find.text('模拟播完'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('stop-current-processing')),
        findsNothing,
      );
      await tester.tap(find.byKey(const ValueKey('toggle-text')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('conversation-input')),
        '文字继续',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('send-text')));
      await tester.pumpAndSettle();
      expect(find.text('文字继续'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('shared page fallback submits once; second failure stays idle', (
    tester,
  ) async {
    await mount(tester);
    await tester.tap(find.text('模拟异常'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('下次识别：备用成功'));
    await tester.pumpAndSettle();
    var gesture = await tester.startGesture(tester.getCenter(button));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('识别回退 1 次'), findsOneWidget);
    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.textContaining('请求 1 次'), findsOneWidget);
    await tester.tap(find.text('模拟异常'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('下次识别：备用也失败'));
    await tester.pumpAndSettle();
    expect(button, findsNothing);
    await tester.tap(find.byKey(const ValueKey('stop-current-processing')));
    await tester.pumpAndSettle();
    gesture = await tester.startGesture(tester.getCenter(button));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.textContaining('语音识别中断'), findsWidgets);
    expect(find.textContaining('请求 1 次'), findsOneWidget);
    expect(find.textContaining('识别回退 2 次'), findsOneWidget);
  });

  testWidgets('58px upwards cancels; pointer cancel and switch never submit', (
    tester,
  ) async {
    await mount(tester);
    var gesture = await tester.startGesture(tester.getCenter(button));
    await tester.pump(const Duration(milliseconds: 400));
    await gesture.moveBy(const Offset(0, -58));
    await tester.pump();
    expect(find.bySemanticsLabel('松开取消'), findsOneWidget);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.textContaining('MOCK：已收到输入'), findsNothing);
    expect(find.byKey(const ValueKey('voice-transcript')), findsNothing);
    gesture = await tester.startGesture(tester.getCenter(button));
    await tester.pump();
    await gesture.cancel();
    await tester.pumpAndSettle();
    gesture = await tester.startGesture(tester.getCenter(button));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('toggle-text')), pointer: 2);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.textContaining('MOCK：已收到输入'), findsNothing);
  });
  testWidgets('denial and background return to safe state without submit', (
    tester,
  ) async {
    await mount(tester);
    await tester.tap(find.text('权限：允许'));
    await tester.pump();
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.textContaining('麦克风未授权'), findsWidgets);
    await tester.tap(find.text('权限：拒绝'));
    await tester.pump();
    final gesture = await tester.startGesture(tester.getCenter(button));
    await tester.pump(const Duration(milliseconds: 400));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    expect(find.textContaining('MOCK：已收到输入'), findsNothing);
  });
  testWidgets(
    'cancel retracts live bubble while keeping history and typed draft',
    (tester) async {
      await mount(tester);
      await tester.tap(find.byKey(const ValueKey('toggle-text')));
      await tester.pumpAndSettle();
      final field = find.byKey(const ValueKey('conversation-input'));
      await tester.enterText(field, '原有历史');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('send-text')));
      await tester.pumpAndSettle();
      final history = tester
          .widget<ConversationPage>(find.byType(ConversationPage))
          .state
          .messages
          .map((m) => (m.id, m.text))
          .toList();
      expect(history, isNotEmpty);
      await tester.enterText(field, '未发送草稿');
      await tester.tap(find.byKey(const ValueKey('toggle-voice')));
      await tester.pumpAndSettle();
      expect(button, findsNothing);
      await tester.tap(find.byKey(const ValueKey('stop-current-processing')));
      await tester.pumpAndSettle();
      final gesture = await tester.startGesture(tester.getCenter(button));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const ValueKey('voice-transcript')), findsOneWidget);
      await gesture.moveBy(const Offset(0, -58));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('voice-transcript')), findsNothing);
      expect(
        tester
            .widget<ConversationPage>(find.byType(ConversationPage))
            .state
            .messages
            .map((m) => (m.id, m.text))
            .toList(),
        history,
      );
      expect(find.textContaining('请求 1 次'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('toggle-text')));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(field).controller!.text, '未发送草稿');
    },
  );
  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(430, 932),
  ]) {
    testWidgets('shared input has no layout exception at $size', (
      tester,
    ) async {
      await mount(tester, size: size);
      await tester.tap(find.byKey(const ValueKey('toggle-text')));
      await tester.pumpAndSettle();
      tester.view.viewInsets = FakeViewPadding(bottom: size.height * .35);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'production host/provider uses shared input and cancels on text switch',
    (tester) async {
      const entry = ConversationEntry(sessionId: 'isolated-production-host');
      final ports = PreviewVoiceInput();
      final fake = VoiceInputFake();
      late ConversationController conversation;
      late ProviderContainer container;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            conversationControllerProvider(entry).overrideWith(
              (ref) => conversation = ConversationController(
                entry: entry,
                accountId: 'isolated',
                gateway: ports,
                history: ports,
              ),
            ),
            conversationPermissionSourceProvider.overrideWithValue(
              InputPermissionFake(),
            ),
            voiceInputAvailableProvider.overrideWithValue(true),
            voiceInputFactoryProvider.overrideWithValue((_) => fake),
            appConfigProvider.overrideWithValue(
              AppConfig.parse(
                environment: 'dev',
                apiBaseUrl: 'https://synthetic.invalid/api/',
              ),
            ),
          ],
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) {
                container = ProviderScope.containerOf(context);
                return ConversationVoiceHost(
                  entry: entry,
                  builder: (binding) => Center(
                    child: VoiceHoldButton(
                      binding: binding,
                      enabled: true,
                      icon: const Icon(Icons.mic),
                      onUnavailable: () {},
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
      final gesture = await tester.startGesture(tester.getCenter(button));
      await tester.pump();
      fake.emit(const VoiceReady());
      await tester.pump();
      expect(fake.starts, 1);
      conversation.toggleInput();
      await tester.pump();
      await gesture.up();
      fake.emit(const VoiceTranscript('不提交', isFinal: true));
      await tester.pump();
      expect(fake.stops, 1);
      expect(ports.commands, isEmpty);
      expect(
        container.read(conversationVoiceProvider(entry)).state.phase,
        VoiceInputPhase.idle,
      );
      conversation.toggleInput();
      await tester.pump();
      final next = await tester.startGesture(tester.getCenter(button));
      await tester.pump(const Duration(milliseconds: 350));
      fake.emit(const VoiceReady());
      await tester.pump();
      await next.up(timeStamp: const Duration(milliseconds: 350));
      fake.emit(const VoiceTranscript('正式装配合成提交', isFinal: true));
      await tester.pumpAndSettle();
      expect(ports.commands.single.message, '正式装配合成提交');
      expect(ports.commands.single.toJson()['channel'], 'voice');
      expect(fake.stops, 2);
      // Switching away and back during hardware shutdown must invalidate
      // the pending result, even if input is eligible again by completion.
      fake.stopGate = Completer<void>();
      final pending = await tester.startGesture(tester.getCenter(button));
      await tester.pump(const Duration(milliseconds: 350));
      fake.emit(const VoiceReady());
      await tester.pump();
      await pending.up(timeStamp: const Duration(milliseconds: 350));
      fake.emit(const VoiceTranscript('停止期间取消', isFinal: true));
      await tester.pump();
      conversation.toggleInput();
      conversation.toggleInput();
      fake.stopGate!.complete();
      await tester.pumpAndSettle();
      expect(ports.commands.length, 1);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );
}
