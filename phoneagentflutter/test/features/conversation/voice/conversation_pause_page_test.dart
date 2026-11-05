import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/conversation_providers.dart';
import 'package:phone_agent/app/conversation_voice_providers.dart';
import 'package:phone_agent/app/task_voice_preference_providers.dart';
import 'package:phone_agent/features/attachments/data/preview_ocr_session.dart';
import 'package:phone_agent/features/attachments/domain/ocr_image_source.dart';
import 'package:phone_agent/features/attachments/presentation/pages/conversation_attachments.dart';
import 'package:phone_agent/features/conversation/domain/agent_protocol.dart';
import 'package:phone_agent/features/conversation/data/voice/preview_voice_input.dart';
import 'package:phone_agent/features/conversation/domain/voice/task_voice_preferences.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_controller.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_speech_controller.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_state.dart';
import 'package:phone_agent/features/conversation/presentation/controller/voice_input_controller.dart';
import 'package:phone_agent/features/conversation/presentation/pages/conversation_page.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/conversation_voice_host.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/voice_composer_binding.dart';
import '../../attachments/ocr_conversation_flow_test.dart'
    show createConversation;
import 'conversation_speech_controller_test.dart' show SpeechFake;

class _Album extends PreviewOcrSession {
  void Function()? onPick;
  @override
  Future<SelectedOcrImage?> pick() async {
    onPick?.call();
    return null;
  }
}

class _Preferences implements TaskVoicePreferenceRepository {
  @override
  Future<TaskVoicePreferences> read() async => const TaskVoicePreferences();
  @override
  Future<void> speech(bool enabled) async {}
  @override
  Future<void> completeGuide() async {}
}

class _Player extends SpeechFake {
  _Player(this.changed);
  final void Function() changed;
  @override
  bool enqueue(String text) {
    final accepted = super.enqueue(text);
    changed();
    return accepted;
  }
}

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    late _Album album;
    late ConversationController conversation;
    late ConversationSpeechController speech;
    late List<SpeechFake> players;
    late VoiceComposerBinding binding;
    const entry = ConversationEntry(sessionId: PreviewOcrSession.sessionId);

    Future<void> mount(WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      });
      album = _Album();
      conversation = createConversation(album);
      players = [];
      speech = conversation.speech = ConversationSpeechController(
        enabled: () => conversation.isOpen,
        factory: (_, changed) {
          final player = _Player(changed)..synthesizing = true;
          players.add(player);
          return player;
        },
      );
      speech.begin();
      final voice = VoiceInputController(
        createSession: () => throw StateError('must not record'),
        permissions: PreviewVoiceInput(),
        endpoint: null,
        isCurrent: () => true,
        canSubmit: () => false,
        submit: (_) => false,
        available: false,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            conversationControllerProvider(
              entry,
            ).overrideWith((_) => conversation),
            conversationVoiceProvider(entry).overrideWith((ref) {
              ref.onDispose(voice.dispose);
              return voice;
            }),
            taskVoicePreferenceRepositoryProvider.overrideWithValue(
              _Preferences(),
            ),
          ],
          child: MaterialApp(
            theme: ThemeData(platform: platform),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: child!,
            ),
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) {
                  final state = ref.watch(
                    conversationControllerProvider(entry),
                  );
                  return ConversationVoiceHost(
                    entry: entry,
                    builder: (value) {
                      binding = value;
                      return ConversationPage(
                        state: state,
                        voice: value,
                        modelName: '测试模型',
                        onClose: conversation.close,
                        onToggle: conversation.toggleInput,
                        onSend: conversation.send,
                        onChoose: conversation.choose,
                        onRetry: () {},
                        onNotice: conversation.showNotice,
                        onModels: () {},
                        onAttachments: () => unawaited(
                          openConversationAttachments(
                            context,
                            ref,
                            conversation,
                            canSend: state.canSend,
                            openDocuments: () async {},
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    void narrate() {
      speech.begin();
      speech.accept(const AgentEvent(AgentEventKind.text, text: '当前播报。'));
    }

    testWidgets(
      '$platform album pauses before native picker without changing task state',
      (tester) async {
        await mount(tester);
        await tester.tap(find.bySemanticsLabel('添加图片'));
        await tester.pumpAndSettle();
        narrate();
        final phase = conversation.state.phase;
        var picked = false;
        album.onPick = () {
          picked = true;
          expect(speech.status, '播报已暂停，可继续交流');
          expect(speech.isActive, isFalse);
          expect(conversation.state.phase, phase);
        };
        await tester.tap(find.text('相册'));
        await tester.pumpAndSettle();
        expect(picked, isTrue);
        expect(find.text('播报已暂停，可继续交流'), findsOneWidget);
        speech.accept(const AgentEvent(AgentEventKind.text, text: '旧回复不重播。'));
        expect(players.single.sentences, ['当前播报。']);
        narrate();
        await tester.pumpAndSettle();
        expect(find.text('播报已暂停，可继续交流'), findsNothing);
        expect(find.text('AI 回复中...'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
      },
    );

    testWidgets(
      '$platform inactive and background keep pause until new input or mute',
      (tester) async {
        await mount(tester);
        narrate();
        await tester.pumpAndSettle();
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        await tester.pumpAndSettle();
        expect(find.text('播报已暂停，可继续交流'), findsOneWidget);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpAndSettle();
        expect(find.text('播报已暂停，可继续交流'), findsOneWidget);
        expect(conversation.state.phase, ConversationPhase.ready);
        binding.onToggleSpeech!();
        await tester.pumpAndSettle();
        expect(speech.status, isEmpty);
        narrate();
        await tester.pumpAndSettle();
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpAndSettle();
        binding.onPress();
        await tester.pumpAndSettle();
        expect(speech.status, isEmpty);
        expect(find.text('播报已暂停，可继续交流'), findsNothing);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
