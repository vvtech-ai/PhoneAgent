import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/call_confirmation.dart';
import 'package:phone_agent/features/conversation/domain/confirmation/call_confirmation_prompt.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/call_confirmation_card.dart';

void main() {
  testWidgets('historical call facts do not ask user to confirm an old call', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CallConfirmationCard(
            confirmation: CallConfirmation.fromPayload({'targetName': '历史目标'}),
          ),
        ),
      ),
    );
    expect(find.text('任务确认'), findsOneWidget);
    expect(find.text(CallConfirmationPrompt.text), findsNothing);
  });
}
