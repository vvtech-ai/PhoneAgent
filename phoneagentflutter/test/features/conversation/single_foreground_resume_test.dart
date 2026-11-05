import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/call_session_providers.dart';
import 'package:phone_agent/app/conversation_providers.dart';
import 'package:phone_agent/features/calls/data/preview_call_flow.dart';
import 'package:phone_agent/features/conversation/domain/history/conversation_history.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_state.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/conversation_voice_host.dart';
import 'package:phone_agent/features/settings/domain/network_availability.dart';

import '../../support/apology_provider_fixture.dart';
import '../../support/confirm_rendered_call.dart';

class _SingleCall extends PreviewCallFlow {
  _SingleCall() : super(CallFlowScenario.single);
  int resultReads = 0;

  @override
  Future<RestoredConversation> restore(String sessionId) {
    resultReads++;
    return super.restore(sessionId);
  }
}

void main() {
  testWidgets('network restoration rechecks only an unfinished single result', (
    tester,
  ) async {
    const entry = ConversationEntry(sessionId: 'session');
    final ports = _SingleCall();
    final fixture = ApologyProviderFixture(
      entry,
      history: ports,
      extra: [
        agentGatewayProvider.overrideWithValue(ports),
        callSessionRepositoryProvider.overrideWithValue(ports),
      ],
    );
    addTearDown(fixture.dispose);
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
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    void recoverNetwork() {
      fixture.network.changes.add(NetworkAvailability.unavailable);
      fixture.network.changes.add(NetworkAvailability.available);
    }

    final initialReads = ports.resultReads;
    recoverNetwork();
    await tester.pump();
    await tester.pump();
    expect(
      ports.resultReads,
      initialReads,
      reason: 'no call needs no result read',
    );

    expect(controller.send('合成需求'), isTrue);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    confirmRenderedCall(controller);
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pump();
    expect(controller.calls!.activeRequest, isNotNull);
    final activeReads = ports.resultReads;
    recoverNetwork();
    await tester.pump();
    await tester.pump();
    expect(
      ports.resultReads,
      activeReads,
      reason: 'active call is not terminal',
    );

    ports.ended = true;
    await tester.pump(const Duration(milliseconds: 500));
    expect(controller.calls!.awaitingOutcome, isTrue);
    ports.outcomeReady = true;
    final pendingReads = ports.resultReads;
    recoverNetwork();
    await tester.pump();
    await tester.pump();
    expect(ports.resultReads, pendingReads + 1);
    expect(controller.calls!.activeRequest, isNull);
    expect(ports.commands, hasLength(2), reason: 'readback must not redial');

    final settledReads = ports.resultReads;
    recoverNetwork();
    await tester.pump();
    await tester.pump();
    expect(
      ports.resultReads,
      settledReads,
      reason: 'settled call is not reread',
    );
    controller.close();
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('network recovery rereads when offline event preceded the page', (
    tester,
  ) async {
    const entry = ConversationEntry(sessionId: 'session');
    final ports = _SingleCall();
    final fixture = ApologyProviderFixture(
      entry,
      history: ports,
      extra: [
        agentGatewayProvider.overrideWithValue(ports),
        callSessionRepositoryProvider.overrideWithValue(ports),
      ],
    );
    addTearDown(fixture.dispose);
    await fixture.open(tester);
    final controller = fixture.container.read(
      conversationControllerProvider(entry).notifier,
    );
    expect(controller.send('合成需求'), isTrue);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    confirmRenderedCall(controller);
    await tester.pump(const Duration(milliseconds: 1500));
    ports.ended = true;
    await tester.pump(const Duration(milliseconds: 500));
    expect(controller.calls!.awaitingOutcome, isTrue);

    fixture.network.changes.add(NetworkAvailability.unavailable);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
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
    ports.outcomeReady = true;
    final pendingReads = ports.resultReads;
    fixture.network.changes.add(NetworkAvailability.available);
    await tester.pump();
    await tester.pump();
    expect(ports.resultReads, pendingReads + 1);
    expect(controller.calls!.activeRequest, isNull);
    expect(ports.commands, hasLength(2));
    controller.close();
    await tester.pumpWidget(const SizedBox());
  });
}
