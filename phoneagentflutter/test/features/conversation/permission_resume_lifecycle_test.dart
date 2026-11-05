import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/agent_context_providers.dart';
import 'package:phone_agent/app/conversation_providers.dart';
import 'package:phone_agent/features/conversation/domain/agent_protocol.dart';
import 'package:phone_agent/features/conversation/domain/context/task_location_permission.dart';
import 'package:phone_agent/features/conversation/domain/tools/conversation_permission.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_state.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/conversation_voice_host.dart';
import '../../support/apology_provider_fixture.dart';
import 'conversation_permission_test.dart' show PermissionFake, signal;

class _Gateway implements AgentGateway {
  final commands = <AgentCommand>[];
  final streams = <StreamController<AgentEvent>>[];
  @override
  AgentRun start(AgentCommand command) {
    commands.add(command);
    final stream = StreamController<AgentEvent>();
    streams.add(stream);
    return AgentRun(stream.stream, () {});
  }
}

class _PreflightGateway implements AgentGateway {
  _PreflightGateway(this.gate);
  final TaskLocationPermission gate;
  final sent = <AgentCommand>[];
  final stream = StreamController<AgentEvent>();
  @override
  AgentRun start(AgentCommand command) {
    var cancelled = false;
    unawaited(() async {
      await gate.prepare(command, () => !cancelled);
      if (!cancelled) sent.add(command);
    }());
    return AgentRun(stream.stream, () => cancelled = true);
  }
}

void main() {
  for (final background in [false, true]) {
    testWidgets(
      'real preflight waits for foreground and restores speech: background=$background',
      (tester) async {
        const entry = ConversationEntry(sessionId: 's');
        final pending = Completer<PermissionGrant>();
        final permissions = PermissionFake()..pendingRequest = pending.future;
        final gate = TaskLocationPermission(permissions);
        final gateway = _PreflightGateway(gate);
        final fixture = ApologyProviderFixture(
          entry,
          extra: [
            agentGatewayProvider.overrideWithValue(gateway),
            taskLocationPermissionProvider.overrideWithValue(gate),
          ],
        );
        addTearDown(fixture.dispose);
        addTearDown(gateway.stream.close);
        await fixture.open(tester);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: fixture.container,
            child: MaterialApp(
              home: ConversationVoiceHost(
                entry: entry,
                builder: (_) => const SizedBox(),
              ),
            ),
          ),
        );
        final controller = fixture.container.read(
          conversationControllerProvider(entry).notifier,
        );
        controller.send('你重新获取定位呀');
        await tester.pump();
        expect(permissions.requests, [false, true]);
        expect(gate.isPending('s'), isTrue);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        await tester.pump();
        if (background) {
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.paused,
          );
          await tester.pump();
        }
        pending.complete(PermissionGrant.denied);
        await tester.pump();
        expect(
          gateway.sent,
          isEmpty,
          reason: 'native result must wait for active owner',
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();
        expect(gateway.sent, hasLength(background ? 0 : 1));
        if (!background) {
          gateway.stream.add(
            const AgentEvent(AgentEventKind.text, text: '定位后首个回复。'),
          );
          gateway.stream.add(const AgentEvent(AgentEventKind.done));
          await tester.pump();
          expect(fixture.players.single.sentences, ['定位后首个回复。']);
        }
        controller.close();
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      },
    );
  }
  for (final background in [false, true]) {
    testWidgets('native permission inactive waits, background=$background', (
      tester,
    ) async {
      const entry = ConversationEntry(sessionId: 's');
      final gateway = _Gateway();
      final pending = Completer<PermissionGrant>();
      final permissions = PermissionFake()..pendingRequest = pending.future;
      final fixture = ApologyProviderFixture(
        entry,
        extra: [
          agentGatewayProvider.overrideWithValue(gateway),
          conversationPermissionSourceProvider.overrideWithValue(permissions),
        ],
      );
      addTearDown(fixture.dispose);
      addTearDown(() async {
        for (final stream in gateway.streams) {
          await stream.close();
        }
      });
      await fixture.open(tester);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: fixture.container,
          child: MaterialApp(
            home: ConversationVoiceHost(
              entry: entry,
              builder: (_) => const SizedBox(),
            ),
          ),
        ),
      );
      final controller = fixture.container.read(
        conversationControllerProvider(entry).notifier,
      );
      controller.send('附近餐厅');
      gateway.streams.single.add(
        const AgentEvent(AgentEventKind.text, text: '旧回复。未完'),
      );
      gateway.streams.single.add(signal());
      await tester.pump();
      expect(permissions.requests, [false, true]);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      if (background) {
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        await tester.pump();
      }
      pending.complete(PermissionGrant.denied);
      await tester.pump();
      expect(
        gateway.commands,
        hasLength(1),
        reason: 'inactive/background must not continue',
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(gateway.commands, hasLength(background ? 1 : 2));
      if (!background) {
        gateway.streams.last.add(
          const AgentEvent(AgentEventKind.text, text: '新回复。'),
        );
        gateway.streams.last.add(const AgentEvent(AgentEventKind.done));
        await tester.pump();
        expect(fixture.players.last.sentences, ['新回复。']);
        expect(
          fixture.players
              .expand((p) => p.sentences)
              .where((s) => s.contains('未完')),
          isEmpty,
        );
      }
      controller.close();
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  }
}
