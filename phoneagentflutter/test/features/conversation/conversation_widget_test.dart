import '../../support/pump_ui_transitions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/conversation_messages.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_state.dart';
import 'package:phone_agent/features/conversation/presentation/pages/conversation_page.dart';

void main() {
  testWidgets('small portrait large font and keyboard leave input accessible', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 568),
            viewInsets: EdgeInsets.only(bottom: 220),
            textScaler: TextScaler.linear(1.3),
          ),
          child: Scaffold(
            body: ConversationPage(
              state: const ConversationState(
                entry: ConversationEntry(sessionId: 's'),
                voiceMode: false,
                messages: [
                  ConversationMessage(
                    id: '1',
                    role: MessageRole.assistant,
                    text: '确认需求',
                  ),
                ],
              ),
              modelName: '模型',
              onClose: () {},
              onToggle: () {},
              onSend: (_) => true,
              onChoose: (_, __) => true,
              onRetry: () {},
              onNotice: (_) {},
              onModels: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpUntilUiSettled();
    expect(tester.takeException(), isNull);
    final semantics = tester.ensureSemantics();
    expect(find.bySemanticsLabel('确认需求'), findsOneWidget);
    semantics.dispose();
    expect(find.byKey(const ValueKey('conversation-input')), findsOneWidget);
    expect(
      tester
          .getBottomRight(find.byKey(const ValueKey('conversation-input')))
          .dy,
      lessThanOrEqualTo(348),
    );
  });
}
