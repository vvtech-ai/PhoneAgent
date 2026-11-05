import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_agent/app/confirmation_billing_providers.dart';
import 'package:phone_agent/features/calls/domain/confirmation_billing.dart';
import 'package:phone_agent/features/calls/presentation/pages/confirmation_billing_route.dart';
import 'package:phone_agent/features/conversation/domain/confirmation/call_confirmation_prompt.dart';
import 'package:phone_agent/features/conversation/domain/confirmation/current_call_confirmation_gate.dart';
import 'package:phone_agent/features/conversation/domain/conversation_messages.dart';
import 'package:phone_agent/features/conversation/domain/agent_protocol.dart';
import 'package:phone_agent/features/conversation/domain/voice/reply_speech_playback.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_controller.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_speech_controller.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_state.dart';
import 'package:phone_agent/features/conversation/presentation/pages/conversation_page.dart';
import 'package:phone_agent/features/tasks/domain/task_records.dart';
import 'package:phone_agent/features/tasks/presentation/controller/task_detail_controller.dart';
import '../../support/confirm_rendered_call.dart';
import '../../support/continuous_task_call_fixture.dart';
import '../conversation/voice/conversation_speech_controller_test.dart'
    show SpeechFake;

const prompt = CallConfirmationPrompt.text;

void main() {
  test(
    'ENTRY-06 VOICE-01: tool-only history never invents a spoken prompt',
    () async {
      final ports = ContinuousTaskCallFixture();
      ports.record('TOOL_REQUESTED', 'historical-command', {
        'toolName': 'makeCall',
        'toolCallId': 'historical-tool',
        'arguments': {'targetName': '合成历史目标', 'phoneNumber': '+12025550101'},
      });
      final controller = ConversationController(
        entry: ConversationEntry(sessionId: ports.session, restore: true),
        accountId: 'synthetic',
        gateway: ports,
        history: ports,
      );
      final player = SpeechFake();
      controller.speech = ConversationSpeechController(
        enabled: () => controller.isOpen,
        factory: (_, __) => player,
      );
      addTearDown(controller.dispose);
      await controller.restore();
      expect(
        controller.state.messages.where((m) => m.confirmation != null),
        hasLength(1),
      );
      expect(controller.state.messages.where((m) => m.text == prompt), isEmpty);
      expect(player.sentences, isEmpty);
      expect(ports.commands, isEmpty);
    },
  );
  for (final attempts in [1, 2]) {
    testWidgets(
      'CONFIRM-01 HISTORY-01: $attempts calls retain prompts, identities and narration',
      (tester) async {
        tester.view.physicalSize = const Size(390, 4000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final ports = ContinuousTaskCallFixture();
        var next = 0;
        final controller = ConversationController(
          entry: const ConversationEntry(sessionId: 'continuous-session'),
          accountId: 'synthetic',
          gateway: ports,
          history: ports,
          callAdmission: ports.admission,
          callSessions: ports,
          nextId: () => 'continuous-${next++}',
        );
        final players = <SpeechFake>[];
        final speech = controller.speech = ConversationSpeechController(
          enabled: () =>
              controller.isOpen && !controller.calls!.snapshot.showCall,
          factory: (_, __) {
            final p = SpeechFake();
            players.add(p);
            return p;
          },
        );
        final remove = controller.calls!.addListener((call) {
          if (call.showCall) {
            speech.pauseForCall();
          } else {
            speech.resumeResult();
          }
        });
        addTearDown(() async {
          remove();
          controller.dispose();
          await ports.close();
        });
        List<String> spoken() => players.expand((p) => p.sentences).toList();
        List<ConversationMessage> prompts() =>
            controller.state.messages.where((m) => m.text == prompt).toList();
        Future<void> show() async {
          final state = controller.state;
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                confirmationBillingProvider.overrideWith(
                  (ref, request) async => const ConfirmationBillingSnapshot(
                    modelTitle: '合成模型',
                    availableBalance: 1000,
                  ),
                ),
              ],
              child: MaterialApp(
                home: Scaffold(
                  body: ConversationPage(
                    state: state,
                    modelName: '合成模型',
                    onClose: () {},
                    onToggle: () {},
                    onSend: (_) => false,
                    onChoose: (_, __) => false,
                    onRetry: () {},
                    onNotice: (_) {},
                    onModels: () {},
                    confirmationBuilder: (message, ordinal) =>
                        ConfirmationBillingRoute(
                          request: ConfirmationBillingRequest.forMessage(
                            state.entry.sessionId,
                            message,
                            ordinal,
                          ),
                          confirmation: message.confirmation!,
                          executable:
                              controller.calls!.activeRequest == null &&
                              CurrentCallConfirmationGate.matches(
                                message: message,
                                request:
                                    controller.calls!.snapshot.launch.request,
                                messages: state.messages,
                              ),
                        ),
                  ),
                ),
              ),
            ),
          );
          await tester.pump();
        }

        for (var call = 1; call <= attempts; call++) {
          expect(controller.send('合成需求$call'), isTrue);
          await tester.pump(const Duration(milliseconds: 1));
          await tester.pump();
          expect(
            ports.confirmed,
            call - 1,
            reason: 'new task must wait for explicit confirmation',
          );
          expect(spoken().where((s) => s == prompt), hasLength(call));
          await show();
          expect(find.text(prompt), findsNWidgets(call));
          expect(prompts(), hasLength(call));
          final currentPrompt = prompts().last;
          final order = controller.state.messages;
          final currentCard = order.lastWhere((m) => m.confirmation != null);
          expect(
            order.indexOf(currentCard),
            lessThan(order.indexOf(currentPrompt)),
          );
          final interrupted = players.last;
          await speech.interrupt();
          expect(interrupted.phase, ReplySpeechPhase.cancelled);
          expect(
            controller.state.messages.any((m) => m.id == currentPrompt.id),
            isTrue,
          );
          if (call > 1) {
            final beforeLate = spoken();
            ports.streams.first.add(
              const AgentEvent(AgentEventKind.text, text: '旧轮迟到音频。'),
            );
            await tester.pump();
            expect(spoken(), beforeLate);
            expect(
              controller.state.messages.any((m) => m.text.contains('旧轮迟到')),
              isFalse,
            );
          }
          confirmRenderedCall(controller);
          await tester.pump(const Duration(milliseconds: 1500));
          await tester.pump();
          await show();
          expect(
            find.text(prompt),
            findsNWidgets(call),
            reason:
                'deactivating the card must retain the already shown prompt',
          );
          expect(
            prompts(),
            hasLength(call),
            reason: 'shown confirmation prose belongs to the timeline',
          );
          final promptId = prompts().last.id;
          expect(ports.confirmed, call);
          expect(
            controller.state.messages.any(
              (m) => m.id == promptId && m.text == prompt,
            ),
            isTrue,
          );
          await tester.pump(const Duration(milliseconds: 1500));
          await tester.pump();
          expect(controller.calls!.snapshot.call!.target.callId, 'call-$call');
          expect(
            controller.state.messages.where((m) => m.receipt != null),
            hasLength(call - 1),
          );
          ports.finish();
          await tester.pump(const Duration(milliseconds: 1500));
          await tester.pump();
          expect(controller.calls!.snapshot.showCall, isFalse);
          expect(spoken().where((s) => s == '合成结果说明$call。'), hasLength(1));
          expect(
            identical(players.last, interrupted),
            isFalse,
            reason:
                'a new valid result may narrate after interruption of the old prompt',
          );
          expect(prompts(), hasLength(call));
          final messages = controller.state.messages;
          final cardIndex = messages.indexWhere(
            (m) => m.toolCallId == 'tool-$call' && m.confirmation != null,
          );
          final promptIndex = messages.indexWhere(
            (m) => m.toolCallId == 'tool-$call' && m.text == prompt,
          );
          final receiptIndex = messages.indexWhere(
            (m) => m.receipt?.attemptId == 'attempt-$call',
          );
          final userIndex = messages.indexWhere(
            (m) => m.role == MessageRole.user && m.text == '确认拨打',
            promptIndex,
          );
          final finalIndex = messages.indexWhere(
            (m) => m.text == '合成结果说明$call。',
          );
          expect(cardIndex, lessThan(promptIndex));
          expect(promptIndex, lessThan(userIndex));
          expect(userIndex, lessThan(receiptIndex));
          expect(receiptIndex, lessThan(finalIndex));
          expect(
            messages
                .where((m) => m.confirmation != null)
                .map((m) => m.toolCallId),
            [for (var index = 1; index <= call; index++) 'tool-$index'],
          );
          expect(
            messages
                .where((m) => m.receipt != null)
                .map((m) => m.receipt!.attemptId),
            [for (var index = 1; index <= call; index++) 'attempt-$index'],
          );
        }
        final commands = ports.commands.length;
        final beforeSpeech = spoken();
        final liveBusiness = _business(controller.state.messages);
        final snapshot = await ports.restore('continuous-session');
        await controller.restore();
        final once = _business(controller.state.messages);
        expect(
          once,
          liveBusiness,
          reason: 'live and restored business facts agree',
        );
        await controller.restore();
        expect(_business(controller.state.messages), once);
        const record = TaskRecord(
          id: 'row',
          kind: TaskRecordKind.conversation,
          title: '合成连续任务',
          status: TaskStatus.completed,
          rawStatus: 'COMPLETED',
          sessionId: 'continuous-session',
        );
        expect(
          _business(TaskDetailState(record, restored: snapshot).messages),
          once,
        );
        expect(
          spoken(),
          beforeSpeech,
          reason: 'history does not replay confirmation or result',
        );
        expect(ports.commands, hasLength(commands));
        expect(commands, attempts * 2);
        expect(controller.calls!.activeRequest, isNull);
        expect(ports.hangups, 0);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}

List<Object?> _business(List<ConversationMessage> messages) => [
  for (final m in messages)
    if (m.thinking == null)
      [
        m.role.name,
        m.text,
        m.toolCallId,
        m.confirmation?.targetName,
        m.receipt?.attemptId,
        m.receipt?.status,
        m.receipt?.headline,
      ],
];
