import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/calls/data/preview_call_flow.dart';
import 'package:phone_agent/features/calls/presentation/pages/conversation_call_host.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_controller.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_state.dart';
import 'package:phone_agent/features/conversation/presentation/pages/conversation_page.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/native_thinking_card.dart';
import '../../support/confirm_rendered_call.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      '$platform physical end and restored pending outcome wait without replay',
      (tester) async {
        final ports = PreviewCallFlow(CallFlowScenario.single);
        var id = 0;
        ConversationController create({bool restore = false}) =>
            ConversationController(
              entry: ConversationEntry(
                sessionId: 'mock-call-flow',
                restore: restore,
              ),
              accountId: 'synthetic',
              gateway: ports,
              history: ports,
              callAdmission: ports.admission,
              callSessions: ports,
              nextId: () => 'c-${id++}',
            );
        final c = create();
        addTearDown(c.dispose);
        c.send('合成需求');
        await tester.pump(const Duration(milliseconds: 1));
        await tester.pump();
        confirmRenderedCall(c);
        await tester.pump(const Duration(milliseconds: 1500));
        await tester.pump();
        Widget page(ConversationController owner) => MaterialApp(
          theme: ThemeData(platform: platform),
          home: Scaffold(
            body: ConversationCallHost(
              controller: owner.calls,
              modelName: 'QwenOmniPlus',
              child: ConversationPage(
                state: owner.state,
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
        );
        await tester.pumpWidget(page(c));
        ports.ended = true;
        await tester.pump(const Duration(seconds: 3));
        await tester.pump();
        expect(c.state.canSend, isTrue);
        expect(c.calls!.snapshot.showCall, isFalse);
        expect(find.byType(NativeThinkingCard), findsOneWidget);
        expect(find.text('· 正在整理通话结果'), findsOneWidget);
        expect(ports.commands, hasLength(2));
        // Restored physical completion resumes read-only outcome observation.
        final history = create(restore: true);
        addTearDown(history.dispose);
        await history.restore();
        await tester.pumpWidget(page(history));
        await tester.pump();
        expect(find.byType(NativeThinkingCard), findsOneWidget);
        expect(ports.commands, hasLength(2));
        await tester.pumpWidget(page(c));
        await tester.pump();
        expect(find.byType(NativeThinkingCard), findsOneWidget);
        ports.outcomeReady = true;
        await tester.pump(const Duration(milliseconds: 1500));
        await tester.pump();
        expect(find.byType(NativeThinkingCard), findsNothing);
        expect(ports.hangups, 0);
        await tester.pumpWidget(const SizedBox());
        c.close();
        history.close();
        await tester.pump();
        expect(tester.takeException(), isNull);
      },
    );
  }
}
