import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/agent_context_providers.dart';
import 'package:phone_agent/app/conversation_providers.dart';
import 'package:phone_agent/features/conversation/domain/agent_protocol.dart';
import 'package:phone_agent/features/conversation/domain/tools/conversation_permission.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_state.dart';
import 'package:phone_agent/features/conversation/presentation/pages/conversation_route.dart';
import 'package:phone_agent/features/conversation/presentation/pages/conversation_page.dart';
import '../../support/apology_provider_fixture.dart';
import '../../support/pump_ui_transitions.dart';

class _Settings
    implements
        ConversationPermissionSource,
        ConversationPermissionSettingsSource {
  final returned = Completer<void>();
  PermissionGrant grant = PermissionGrant.blocked;
  int opens = 0;
  final requests = <bool>[];
  @override
  Future<void> openSettings() {
    opens++;
    return returned.future;
  }

  @override
  Future<PermissionGrant> resolve(
    ConversationPermission permission, {
    required bool request,
  }) async {
    requests.add(request);
    return grant;
  }
}

class _Gateway implements AgentGateway {
  final commands = <AgentCommand>[];
  @override
  AgentRun start(AgentCommand command) {
    commands.add(command);
    return AgentRun(
      Stream.fromIterable(const [
        AgentEvent(AgentEventKind.text, text: '已收到。'),
        AgentEvent(AgentEventKind.done),
      ]),
      () {},
    );
  }
}

void main() {
  for (final scenario in ['granted', 'denied', 'new-turn']) {
    testWidgets(
      'task settings $scenario reads actual grant and owns its turn',
      (tester) async {
        const entry = ConversationEntry(sessionId: 'settings');
        final settings = _Settings();
        final gateway = _Gateway();
        final fixture = ApologyProviderFixture(
          entry,
          extra: [
            conversationPermissionSourceProvider.overrideWithValue(settings),
            agentGatewayProvider.overrideWithValue(gateway),
          ],
        );
        addTearDown(fixture.dispose);
        await fixture.open(tester);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: fixture.container,
            child: const MaterialApp(home: ConversationRoute(entry: entry)),
          ),
        );
        await fixture.complete(tester);
        final owned = tester
            .widget<ConversationPage>(find.byType(ConversationPage))
            .state
            .entry;
        final controller = fixture.container.read(
          conversationControllerProvider(owned).notifier,
        );
        controller.showNotice(locationPermissionSettingsNotice);
        await tester.pumpUntilUiSettled();
        await tester.tap(find.text('去设置'));
        await tester.pump();
        expect(settings.opens, 1);
        expect(gateway.commands, isEmpty);
        if (scenario == 'new-turn') {
          expect(controller.send('改订明天'), isTrue);
          await tester.pump(const Duration(milliseconds: 500));
          await tester.pump();
          expect(controller.state.canSend, isTrue);
        }
        settings.grant = scenario == 'denied'
            ? PermissionGrant.blocked
            : PermissionGrant.granted;
        settings.returned.complete();
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump();
        expect(
          gateway.commands.map((c) => c.message).toList(),
          switch (scenario) {
            'granted' => ['重新获取定位'],
            'new-turn' => ['改订明天'],
            _ => <String>[],
          },
        );
        expect(gateway.commands.every((c) => c.actionId == null), isTrue);
        expect(settings.requests.every((request) => !request), isTrue);
        if (scenario == 'denied') {
          expect(find.textContaining('定位权限仍未开启'), findsOneWidget);
        }
        controller.close();
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      },
    );
  }
}
