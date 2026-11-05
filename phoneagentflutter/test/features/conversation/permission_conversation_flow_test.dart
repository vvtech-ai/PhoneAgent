import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/agent_protocol.dart';
import 'package:phone_agent/features/conversation/domain/conversation_messages.dart';
import 'package:phone_agent/features/conversation/domain/history/conversation_history.dart';
import 'package:phone_agent/features/conversation/domain/history/ledger_event.dart';
import 'package:phone_agent/features/conversation/domain/tools/conversation_permission.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_controller.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_state.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_speech_controller.dart';
import 'voice/conversation_speech_controller_test.dart' show SpeechFake;
import 'conversation_permission_test.dart' show PermissionFake, signal;

void main() {
  late _Gateway gateway;
  late _History history;
  late PermissionFake permissions;
  late ConversationController controller;
  late ConversationState state;
  setUp(() {
    gateway = _Gateway();
    history = _History();
    permissions = PermissionFake();
    var id = 0;
    controller = ConversationController(
      entry: const ConversationEntry(sessionId: 's'),
      accountId: 'user',
      gateway: gateway,
      history: history,
      permissions: permissions,
      nextId: () => 'c${++id}',
    );
    controller.addListener((s) => state = s);
  });
  tearDown(() async {
    controller.dispose();
    for (final stream in gateway.streams) {
      await stream.close();
    }
  });
  Future<void> flush() => Future<void>.delayed(Duration.zero);

  for (final grant in [PermissionGrant.granted, PermissionGrant.denied]) {
    test(
      'interrupted permission reply resumes fresh speech for $grant',
      () async {
        final players = <SpeechFake>[];
        controller.speech = ConversationSpeechController(
          enabled: () => true,
          factory: (_, __) {
            final player = SpeechFake();
            players.add(player);
            return player;
          },
        );
        final pending = Completer<PermissionGrant>();
        permissions.pendingRequest = pending.future;
        controller.send('附近餐厅');
        final old = gateway.streams.single;
        old.add(const AgentEvent(AgentEventKind.text, text: '弹窗前。未完'));
        old.add(signal());
        await flush();
        expect(permissions.requests, [false, true]);
        await controller.speech!.interrupt();
        pending.complete(grant);
        await flush();
        expect(gateway.commands.last.actionId, 'permission_result');
        old.add(const AgentEvent(AgentEventKind.done));
        gateway.streams.last.add(
          const AgentEvent(AgentEventKind.text, text: '权限后第一句。'),
        );
        await flush();
        gateway.streams.last.add(
          const AgentEvent(AgentEventKind.text, text: '权限后第二句。'),
        );
        gateway.streams.last.add(const AgentEvent(AgentEventKind.done));
        await flush();
        expect(players.map((p) => p.sentences).toList(), [
          ['弹窗前。', '需要你授权后才能继续'],
          ['权限后第一句。', '权限后第二句。'],
        ]);
      },
    );
  }

  test(
    'new action cancels old stream, no user echo, old done cannot end new action',
    () async {
      controller.send('合成请求');
      final old = gateway.streams.single;
      old.add(signal());
      old.add(const AgentEvent(AgentEventKind.done));
      await flush();
      expect(gateway.commands, hasLength(2));
      expect(gateway.cancellations, 1);
      final action = gateway.commands.last;
      expect(action.actionId, 'permission_result');
      expect(action.actionPayload!['status'], 'OK');
      expect(action.message, isNull);
      expect(
        state.messages.where((m) => m.role == MessageRole.user),
        hasLength(1),
      );
      expect(state.phase, ConversationPhase.sending);
      gateway.streams.last.add(
        const AgentEvent(
          AgentEventKind.finalResponse,
          sessionId: 's',
          text: '继续补问',
          payload: {'type': 'TEXT_REPLY'},
        ),
      );
      gateway.streams.last.add(const AgentEvent(AgentEventKind.done));
      await flush();
      expect(state.phase, ConversationPhase.ready);
      expect(state.messages.last.text, '继续补问');
      expect(controller.send('后续文字'), true);
      expect(gateway.commands.last.sessionId, 's');
      expect(gateway.commands.last.actionId, isNull);
    },
  );
  test(
    'closing during native prompt never submits action or updates state',
    () async {
      final pending = Completer<PermissionGrant>();
      permissions.pendingRequest = pending.future;
      controller.send('请求');
      gateway.streams.single.add(signal());
      await flush();
      controller.close();
      pending.complete(PermissionGrant.granted);
      await flush();
      expect(gateway.commands, hasLength(1));
      expect(state.phase, ConversationPhase.closed);
      expect(state.messages, isEmpty);
    },
  );
  test('wrong-session permission signal never invokes device port', () async {
    controller.send('请求');
    gateway.streams.single.add(
      AgentEvent(
        AgentEventKind.signal,
        sessionId: 'other',
        payload: signal().payload,
      ),
    );
    await flush();
    expect(permissions.requests, isEmpty);
    expect(gateway.commands, hasLength(1));
  });
  test(
    'restoring live-looking pending permission does not replay it',
    () async {
      history.pending = true;
      await controller.restore();
      expect(state.pendingToolCallId, 'tool');
      expect(permissions.requests, isEmpty);
      expect(gateway.commands, isEmpty);
      expect(state.canSend, true);
    },
  );
  test(
    'duplicate permission in continuation does not issue third command',
    () async {
      controller.send('请求');
      gateway.streams.single.add(signal());
      await flush();
      gateway.streams.last.add(signal());
      gateway.streams.last.add(const AgentEvent(AgentEventKind.done));
      await flush();
      expect(gateway.commands, hasLength(2));
      expect(permissions.requests, [false, true]);
      expect(state.phase, ConversationPhase.ready);
    },
  );
}

class _Gateway implements AgentGateway {
  final commands = <AgentCommand>[];
  final streams = <StreamController<AgentEvent>>[];
  int cancellations = 0;
  @override
  AgentRun start(AgentCommand command) {
    commands.add(command);
    final stream = StreamController<AgentEvent>();
    streams.add(stream);
    return AgentRun(stream.stream, () => cancellations++);
  }
}

class _History implements ConversationHistoryRepository {
  bool pending = false;
  @override
  Future<RestoredConversation> restore(String sessionId) async =>
      RestoredConversation(
        const ConversationDetail(
          sessionId: 's',
          title: '',
          status: 'WAITING_USER',
        ),
        ledger: LedgerSnapshot(
          's',
          pending ? 1 : 0,
          const LedgerProjection(
            status: 'WAITING_USER',
            continuable: true,
            pendingRestorable: true,
            migrationStatus: 'NATIVE',
            projectedThrough: 1,
          ),
          [
            if (pending)
              LedgerEvent(
                eventId: 'e',
                sessionId: 's',
                sequence: 1,
                type: 'TOOL_REQUESTED',
                schemaVersion: 1,
                commandId: 'previous',
                payload: {
                  'toolName': 'requestPermission',
                  'toolCallId': 'tool',
                  'modelTurnId': 'model',
                  'toolOrdinal': 0,
                  'displayPayloadVersion': 1,
                  'arguments': {'permissionKey': 'contacts', 'reason': '合成请求'},
                },
              ),
          ],
        ),
      );
}
