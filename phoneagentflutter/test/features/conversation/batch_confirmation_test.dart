import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/batch_confirmation.dart';
import 'package:phone_agent/features/conversation/domain/call_confirmation.dart';
import 'package:phone_agent/features/conversation/domain/conversation_messages.dart';
import 'package:phone_agent/features/conversation/domain/conversation_message_merge.dart';
import 'package:phone_agent/features/conversation/domain/conversation_live_messages.dart';
import 'package:phone_agent/features/conversation/domain/history/ledger_event.dart';
import '../../../tool/previews/shell_batch_confirmation.dart';

void main() {
  test(
    'v65 generic prompts stay hidden while meaningful assistant text remains',
    () {
      for (final text in ['需要你补充信息', '需要你补充信息。', '请补充信息', '请补充必要信息', '请语音回答']) {
        expect(
          BatchConfirmation.request({
            ...ShellBatchConfirmation.request('x'),
            'assistantText': text,
          })!.showsAssistantText,
          isFalse,
        );
      }
      expect(
        BatchConfirmation.request(
          ShellBatchConfirmation.request('x'),
        )!.showsAssistantText,
        isTrue,
      );
    },
  );
  LedgerEvent event(
    int n,
    String type,
    Map<String, Object?> payload, {
    int schema = 1,
    String command = 'turn',
  }) => LedgerEvent(
    eventId: 'event$n',
    sessionId: 'session',
    sequence: n,
    type: type,
    schemaVersion: schema,
    commandId: command,
    payload: payload,
  );
  Map<String, Object?> result(String decision) => {
    'toolName': 'confirmBatchTask',
    'toolCallId': 'snapshot',
    'ordinal': 99,
    'result': {'decision': decision},
  };
  for (final string in [false, true]) {
    test(
      'structured snapshot and result preserve identity/order, string=$string',
      () {
        final payload = {
          ...ShellBatchConfirmation.request('snapshot'),
          'ordinal': 2,
          'arguments': {
            'snapshotJson': string
                ? jsonEncode(ShellBatchConfirmation.snapshot)
                : ShellBatchConfirmation.snapshot,
          },
        };
        final messages = ConversationMessages.project([
          event(
            3,
            'TOOL_RESULT_RECORDED',
            result('CONFIRMED'),
            command: 'reply',
          ),
          event(1, 'TOOL_REQUESTED', payload),
          event(2, 'USER_TURN_ACCEPTED', {'text': '确认'}, command: 'reply'),
        ]);
        expect(messages.length, 2);
        final message = messages.first, card = message.batchConfirmation!;
        expect(message.id, 'ledger:batch-confirmation:snapshot');
        expect(message.commandId, 'turn');
        expect(card.version, 3);
        expect(card.billingAlias, 'batch-plus:snapshot:3');
        expect(card.decision, BatchConfirmationDecision.confirmed);
        expect(card.capturesBilling, isFalse);
        expect(card.sections.first.rows.first.value, '合成迁移评审');
        expect(card.recipients.length, 5);
        expect(
          (card.originalCount, card.callableCount, card.skippedCount),
          (6, 5, 1),
        );
        expect(card.issues.single.value, contains('缺少号码'));
        expect(card.assistantText, contains('请确认'));
      },
    );
  }
  test(
    'decision changes same card and only first confirmed execution card is suppressed',
    () {
      final facts = [
        event(1, 'TOOL_REQUESTED', ShellBatchConfirmation.request('snapshot')),
      ];
      for (final wire in [
        'REVISION_REQUESTED',
        'CANCELLED',
        'unknown',
        'CONFIRMED',
      ]) {
        final messages = ConversationMessages.project([
          ...facts,
          event(2, 'TOOL_RESULT_RECORDED', result(wire)),
        ]);
        expect(
          messages.single.batchConfirmation!.decision,
          BatchConfirmationDecision.fromWire(wire),
        );
      }
      final projected = ConversationMessages.project([
        ...facts,
        event(2, 'TOOL_RESULT_RECORDED', result('CONFIRMED')),
        event(3, 'TOOL_REQUESTED', ShellBatchConfirmation.execution('session')),
        event(4, 'TOOL_REQUESTED', {
          ...ShellBatchConfirmation.execution('session'),
          'toolCallId': 'second',
        }),
      ]);
      expect(projected.where((m) => m.batchConfirmation != null).length, 1);
      expect(
        projected.where((m) => m.confirmation != null).single.toolCallId,
        'second',
      );
    },
  );
  test(
    'unsupported/malformed request is not an invented card; revised turn is removed',
    () {
      final valid = ShellBatchConfirmation.request('snapshot');
      for (final payload in [
        {...valid, 'displayPayloadVersion': 2},
        {...valid, 'toolCallId': ''},
        {
          ...valid,
          'arguments': {'snapshotJson': '{bad'},
        },
        {
          ...valid,
          'arguments': {'snapshotJson': []},
        },
      ]) {
        expect(
          ConversationMessages.project([event(1, 'TOOL_REQUESTED', payload)]),
          isEmpty,
        );
      }
      expect(
        ConversationMessages.project([
          event(1, 'TOOL_REQUESTED', valid, schema: 2),
        ]),
        isEmpty,
      );
      expect(
        ConversationMessages.project([
          event(1, 'TOOL_REQUESTED', valid),
          event(2, 'RUN_CANCELLED', {'stage': 'recovery_revision'}),
        ]),
        isEmpty,
      );
    },
  );
  test(
    'audit fallback respects non-runnable markers and exact malformed array positions',
    () {
      final card = BatchConfirmation.request({
        ...ShellBatchConfirmation.request('x'),
        'arguments': {
          'snapshotJson': {
            'recipients': [
              null,
              {'phoneNumber': '100', 'status': 'READY'},
              {'targetName': '乙', 'phoneNumber': '101', 'status': 'MISSING'},
              {'targetName': '丙', 'phoneNumber': ''},
            ],
          },
        },
      })!;
      expect(card.recipients.first.id, 'x:recipient:1');
      expect(card.recipients.first.displayName, '100');
      expect(
        (card.originalCount, card.callableCount, card.skippedCount),
        (3, 1, 2),
      );
    },
  );
  test(
    'resolved phone aliases remain callable in the confirmation and call spec',
    () {
      final payload = {
        ...ShellBatchConfirmation.request('phone-alias'),
        'arguments': {
          'snapshotJson': {
            'title': '会议邀请',
            'recipients': [
              {
                'itemId': 'du-yan',
                'targetName': '杜艳',
                'mobile': '13800138000',
                'status': 'READY',
              },
            ],
          },
        },
      };
      final card = BatchConfirmation.request(payload)!;
      expect(card.recipients.single.phone, '13800138000');
      expect(card.recipients.single.runnable, isTrue);

      final call = CallConfirmation.fromPayload({
        'recipientsJson': jsonEncode([
          {'targetName': '杜艳', 'contactPhone': '13800138000'},
        ]),
        'primaryGoal': '会议邀请',
      }, batch: true);
      expect(call.phoneNumber, '13800138000');
    },
  );
  test(
    'durable card replaces same ASK_USER and tool trace but keeps later streaming text',
    () {
      final durable = ConversationMessages.project([
        event(1, 'TOOL_REQUESTED', ShellBatchConfirmation.request('snapshot')),
      ]);
      final overlays = [
        ConversationLiveMessages.assistant(
          'turn',
          durable.single.text,
          [],
          'snapshot',
        ),
        ConversationLiveMessages.toolCard('turn', {
          'toolCallId': 'snapshot',
          'toolName': 'confirmBatchTask',
        }),
        ConversationLiveMessages.assistant('turn', '新的流式说明', [], null),
      ];
      final merged = ConversationMessageMerge.merge(durable, overlays);
      expect(merged.length, 2);
      expect(merged.last.text, '新的流式说明');
    },
  );
}
