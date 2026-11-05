import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/conversation_message_merge.dart';
import 'package:phone_agent/features/conversation/domain/conversation_messages.dart';
import 'package:phone_agent/features/conversation/domain/history/conversation_source_steps.dart';
import 'package:phone_agent/features/conversation/domain/history/ledger_event.dart';
import 'package:phone_agent/features/conversation/domain/membership_denial_reply.dart';
import '../../../tool/previews/shell_batch_confirmation.dart';

LedgerEvent failure(String code, {int version = 1, int sequence = 2}) =>
    LedgerEvent(
      eventId: 'failure-$sequence',
      sessionId: 'session',
      sequence: sequence,
      type: 'RUN_FAILED',
      schemaVersion: version,
      commandId: 'command',
      payload: {'reason': code, 'stage': 'tool', 'retryable': false},
    );

void main() {
  for (final code in [
    'BATCH_CONCURRENCY_LIMIT',
    'BATCH_CONTACT_LIMIT',
    'BATCH_ENTITLEMENT_LIMIT',
    'CALL_CONCURRENCY_LIMIT',
    'MODEL_ENTITLEMENT_DENIED',
    'ENTITLEMENT_DENIED',
  ]) {
    test('$code restores the same durable assistant reply from history', () {
      final event = failure(code);
      final messages = ConversationMessages.project([event]);
      expect(messages, hasLength(1));
      expect(messages.single.id, 'ledger:${event.eventId}');
      expect(messages.single.commandId, 'command');
      expect(messages.single.text, MembershipDenialReply.message(code));
      expect(messages.single.role, MessageRole.assistant);
      expect(messages.single.transient, isFalse);
      final steps = ConversationSourceSteps.project([event]);
      expect(steps, hasLength(1));
      expect(steps.single.aliases, contains(messages.single.id));
    });
  }

  test('durable denial replaces its live overlay without a duplicate', () {
    final event = failure('BATCH_CONCURRENCY_LIMIT');
    final messages =
        ConversationMessageMerge.merge(ConversationMessages.project([event]), [
          ConversationMessage(
            id: 'live-denial',
            role: MessageRole.assistant,
            commandId: 'command',
            text: MembershipDenialReply.message('BATCH_CONCURRENCY_LIMIT')!,
            transient: true,
          ),
        ]);
    expect(messages, hasLength(1));
    expect(messages.single.id, 'ledger:${event.eventId}');
    expect(messages.single.transient, isFalse);
  });

  test('unknown errors and unknown schema do not expose raw diagnostics', () {
    final events = [
      failure('private upstream error'),
      failure('BATCH_CONCURRENCY_LIMIT', version: 2, sequence: 3),
    ];
    expect(ConversationMessages.project(events), isEmpty);
    expect(ConversationSourceSteps.project(events), isEmpty);
  });

  test('later successful turns do not erase an earlier refusal', () {
    final events = [
      failure('BATCH_CONCURRENCY_LIMIT'),
      LedgerEvent(
        eventId: 'reply',
        sessionId: 'session',
        sequence: 4,
        type: 'ASSISTANT_TURN_COMMITTED',
        schemaVersion: 1,
        commandId: 'next-command',
        payload: {'text': '已更新任务'},
      ),
    ];
    final messages = ConversationMessages.project(events.reversed);
    expect(messages.map((m) => m.id), ['ledger:failure-2', 'ledger:reply']);
  });

  test('batch contact limit removes only failed execution cards', () {
    LedgerEvent event(
      int n,
      String type,
      String command,
      Map<String, Object?> payload,
    ) => LedgerEvent(
      eventId: 'event-$n',
      sessionId: 'session',
      sequence: n,
      type: type,
      schemaVersion: 1,
      commandId: command,
      payload: payload,
    );
    final execution = ShellBatchConfirmation.execution('session');
    final events = [
      event(
        1,
        'TOOL_REQUESTED',
        'confirm',
        ShellBatchConfirmation.request('snapshot'),
      ),
      event(2, 'TOOL_RESULT_RECORDED', 'first', {
        'toolName': 'confirmBatchTask',
        'toolCallId': 'snapshot',
        'resultStatus': 'completed',
        'result': {'decision': 'CONFIRMED'},
      }),
      event(3, 'TOOL_REQUESTED', 'first', execution),
      event(4, 'RUN_FAILED', 'first', {'reason': 'BATCH_CONTACT_LIMIT'}),
      event(5, 'TOOL_RESULT_RECORDED', 'second', {
        'toolName': 'makeBatchCalls',
        'toolCallId': execution['toolCallId'],
        'resultStatus': 'cancelled',
        'result': {},
      }),
      event(6, 'TOOL_REQUESTED', 'second', {
        ...execution,
        'toolCallId': 'second-execution',
      }),
      event(7, 'RUN_FAILED', 'second', {'reason': 'BATCH_CONTACT_LIMIT'}),
      event(8, 'TOOL_RESULT_RECORDED', 'third', {
        'toolName': 'makeBatchCalls',
        'toolCallId': 'second-execution',
        'resultStatus': 'completed',
        'result': {},
      }),
      event(9, 'TOOL_REQUESTED', 'third', {
        ...execution,
        'toolCallId': 'third-execution',
      }),
      event(10, 'RUN_FAILED', 'third', {'reason': 'BATCH_CONTACT_LIMIT'}),
    ];
    final messages = ConversationMessages.project(events);
    expect(messages.where((m) => m.confirmation != null), isEmpty);
    expect(messages.where((m) => m.batchConfirmation != null), hasLength(1));
    expect(
      messages.where((m) => m.batchConfirmation != null).single.id,
      'ledger:batch-confirmation:snapshot',
    );
    expect(
      messages.where(
        (m) => m.text == MembershipDenialReply.message('BATCH_CONTACT_LIMIT'),
      ),
      hasLength(3),
    );
    final steps = ConversationSourceSteps.project(events);
    expect(
      steps.where((s) => s.id.startsWith('ledger:call-confirmation:')),
      isEmpty,
    );
    expect(
      steps.where((s) => s.id == 'ledger:batch-confirmation:snapshot'),
      hasLength(1),
    );
  });
}
