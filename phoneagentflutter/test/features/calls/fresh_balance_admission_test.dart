import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/calls/domain/call_admission.dart';
import 'package:phone_agent/features/calls/data/preview_call_flow.dart';
import 'package:phone_agent/features/conversation/domain/agent_protocol.dart';
import 'package:phone_agent/features/conversation/data/stream/agent_event_decoder.dart';
import 'package:phone_agent/features/conversation/data/stream/sse_frame_decoder.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_controller.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_speech_controller.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_state.dart';
import '../../support/call_admission_fixture.dart';
import '../../support/confirm_rendered_call.dart';
import '../conversation/voice/conversation_speech_controller_test.dart'
    show SpeechFake;
import '../conversation/voice/conversation_speech_integration_test.dart'
    show ReplyGateway;
import '../conversation/voice/committed_reply_narration_test.dart' show reply;

void main() {
  for (final batch in [false, true]) {
    test(
      'SDK points rejection refreshes and narrates once without another dial, batch=$batch',
      () async {
        final fixture = AdmissionFixture();
        final gateway = ReplyGateway();
        final ports = PreviewCallFlow(CallFlowScenario.single);
        final controller = ConversationController(
          entry: const ConversationEntry(sessionId: 'session'),
          accountId: 'synthetic',
          gateway: gateway,
          history: ports,
          callAdmission: fixture.service,
          callSessions: ports,
        );
        final players = <SpeechFake>[];
        controller.speech = ConversationSpeechController(
          enabled: () => controller.isOpen,
          factory: (_, __) {
            final player = SpeechFake();
            players.add(player);
            return player;
          },
        );
        addTearDown(() {
          controller.dispose();
          unawaited(gateway.events.close());
        });
        controller.send('合成任务');
        const notice = '积分不足，本次未发起外呼。';
        final rejected = const AgentEventDecoder().decode(
          SseFrame(
            'task_failed',
            jsonEncode({
              'sessionId': 'session',
              'displayMessage': notice,
              'data': batch
                  ? {
                      'batchCallResult': {
                        'status': 'FAILED',
                        'resultCode': 'POINTS_INSUFFICIENT_BALANCE',
                        'items': [],
                      },
                    }
                  : {
                      'callResult': {
                        'status': 'FAILED',
                        'metadata': {
                          'resultCode': 'POINTS_INSUFFICIENT_BALANCE',
                        },
                      },
                    },
            }),
          ),
        );
        final fact = reply(
          sequence: 1,
          session: 'session',
          text: notice,
          reason: batch ? 'batch_call_result' : 'call_result',
        );
        gateway.events.add(
          AgentEvent(
            AgentEventKind.committed,
            sessionId: 'session',
            ledger: fact,
          ),
        );
        gateway.events.add(rejected);
        gateway.events.add(rejected);
        await Future<void>.delayed(Duration.zero);
        expect(fixture.refreshes, 1);
        expect(
          players.expand((p) => p.sentences).where((s) => s == notice),
          hasLength(1),
        );
        expect(ports.commands, isEmpty);
        expect(controller.state.notice, isNot(contains('服务暂时不可用')));
      },
    );
  }
  test(
    'first confirmation detects balance reduced after card opened',
    () async {
      final fixture = AdmissionFixture()
        ..balance = 1000
        ..refreshed = 0;
      final decision = await fixture.service.evaluate(
        callRequest(),
        priorRequests: [],
        isCurrent: () => true,
      );
      expect(decision!.kind, CallAdmissionKind.firstInsufficient);
      expect(decision.balance, 0);
      expect(fixture.refreshes, 1);
    },
  );

  test(
    'first refresh can observe top-up instead of blocking old balance',
    () async {
      final fixture = AdmissionFixture()
        ..balance = 0
        ..refreshed = 1000;
      final decision = await fixture.service.evaluate(
        callRequest(),
        priorRequests: [],
        isCurrent: () => true,
      );
      expect(decision!.kind, CallAdmissionKind.allow);
      expect(fixture.refreshes, 1);
    },
  );

  test('late refresh cannot admit after conversation closed', () async {
    final fixture = AdmissionFixture();
    final pending = Completer<int?>();
    fixture.onRefresh = () => pending.future;
    var current = true;
    final evaluated = fixture.service.evaluate(
      callRequest(),
      priorRequests: [],
      isCurrent: () => current,
    );
    await Future<void>.delayed(Duration.zero);
    current = false;
    pending.complete(1000);
    expect(await evaluated, isNull);
    expect(fixture.commits, 0);
  });

  for (final muted in [false, true]) {
    testWidgets(
      'fresh insufficient balance blocks dial and narrates once, muted=$muted',
      (tester) async {
        final fixture = AdmissionFixture()
          ..balance = 1000
          ..refreshed = 0;
        final ports = PreviewCallFlow(CallFlowScenario.single);
        final players = <SpeechFake>[];
        final controller = ConversationController(
          entry: const ConversationEntry(sessionId: 'mock-call-flow'),
          accountId: 'synthetic',
          gateway: ports,
          history: ports,
          callAdmission: fixture.service,
          callSessions: ports,
        );
        controller.speech = ConversationSpeechController(
          enabled: () => controller.isOpen && !muted,
          factory: (_, __) {
            final player = SpeechFake();
            players.add(player);
            return player;
          },
        );
        addTearDown(controller.dispose);
        controller.send('合成测试任务');
        await tester.pump(const Duration(milliseconds: 1));
        await tester.pump();
        confirmRenderedCall(controller);
        await tester.pump(const Duration(milliseconds: 1500));
        await tester.pump();
        expect(ports.commands, hasLength(1));
        expect(fixture.refreshes, 1);
        expect(
          controller.state.messages.where((m) => m.text.startsWith('积分不足')),
          hasLength(1),
        );
        final notices = players
            .expand((p) => p.sentences)
            .where((s) => s.startsWith('积分不足'));
        expect(notices, muted ? isEmpty : hasLength(1));
        expect(controller.state.notice, isNot(contains('服务暂时不可用')));
        controller.close();
      },
    );
  }
}
