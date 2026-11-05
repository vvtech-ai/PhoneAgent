import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/calls/domain/call_launch_request.dart';
import 'package:phone_agent/features/conversation/domain/call_confirmation.dart';
import 'package:phone_agent/features/conversation/domain/confirmation/current_call_confirmation_gate.dart';
import 'package:phone_agent/features/conversation/domain/conversation_messages.dart';
import 'package:phone_agent/features/conversation/domain/receipts/call_receipt.dart';
import 'package:phone_agent/features/conversation/domain/history/call_request_history.dart';
import 'package:phone_agent/features/conversation/domain/history/ledger_event.dart';

const _spec = {
  'targetName': '合成目标',
  'phoneNumber': '10086',
  'primaryGoal': '合成任务',
};

ConversationMessage _card(String id, String tool, Map<String, Object?> spec) =>
    ConversationMessage(
      id: id,
      role: MessageRole.assistant,
      text: '',
      toolCallId: tool,
      confirmation: CallConfirmation.fromPayload(spec),
    );

void main() {
  test(
    'real restored request retains authorization for its displayed card',
    () {
      final facts = [
        LedgerEvent(
          eventId: 'e',
          sessionId: 's',
          sequence: 1,
          type: 'TOOL_REQUESTED',
          schemaVersion: 1,
          commandId: 'c',
          payload: {
            'toolName': 'makeCall',
            'toolCallId': 'tool',
            'arguments': _spec,
          },
        ),
      ];
      final messages = ConversationMessages.project(facts);
      final request = CallRequestHistory.project('s', facts).single;
      final card = messages.singleWhere((m) => m.confirmation != null);
      expect(
        CurrentCallConfirmationGate.matches(
          message: card,
          request: request,
          messages: messages,
        ),
        isTrue,
      );
    },
  );
  final request = CallLaunchRequest(
    sessionId: 'session',
    toolId: 'pending',
    commandId: 'command',
    ordinal: 1,
    spec: _spec,
  );
  bool matches(ConversationMessage card, List<ConversationMessage> messages) =>
      CurrentCallConfirmationGate.matches(
        message: card,
        request: request,
        messages: messages,
      );

  test('same tool id cannot authorize a different displayed specification', () {
    final card = _card('card', 'pending', {..._spec, 'phoneNumber': '10010'});
    expect(matches(card, [card]), isFalse);
  });
  test('matching current card ignores harmless map key insertion order', () {
    final card = _card('card', 'pending', {
      'primaryGoal': '合成任务',
      'phoneNumber': '10086',
      'targetName': '合成目标',
    });
    expect(matches(card, [card]), isTrue);
  });
  test('same specification with another tool id remains historical', () {
    final card = _card('card', 'old', _spec);
    expect(matches(card, [card]), isFalse);
  });
  test('a later receipt prevents an older card from authorizing a call', () {
    final card = _card('card', 'pending', _spec);
    expect(
      matches(card, [
        card,
        ConversationMessage(
          id: 'receipt',
          role: MessageRole.assistant,
          text: '',
          receipt: CallReceipt(attemptId: 'attempt', status: 'FAILED'),
        ),
      ]),
      isFalse,
    );
  });
  test(
    'a newer confirmation owns presentation even with identical details',
    () {
      final old = _card('old', 'pending', _spec);
      final next = _card('new', 'next', _spec);
      expect(matches(old, [old, next]), isFalse);
    },
  );
}
