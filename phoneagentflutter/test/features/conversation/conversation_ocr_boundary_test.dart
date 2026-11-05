import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/conversation_messages.dart';
import 'package:phone_agent/features/conversation/domain/history/conversation_ocr_boundary.dart';
import 'package:phone_agent/features/conversation/domain/history/conversation_source_steps.dart';
import 'package:phone_agent/features/conversation/domain/history/ledger_event.dart';

void main() {
  ConversationOcrBoundary boundary(List<LedgerEvent> events) =>
      ConversationOcrBoundary.project(
        events,
        ConversationMessages.project(events),
      );
  test('OCR and transport/status events never consume source steps', () {
    final events = [
      _e(1, 'USER_TURN_ACCEPTED', {'text': '用户'}),
      _e(2, 'OCR_IMAGE_COMMITTED', {}),
      _e(3, 'SESSION_STATUS_CHANGED', {}),
      _e(4, 'ASSISTANT_TURN_COMMITTED', {'text': '回复'}),
    ];
    final b = boundary(events);
    expect(b.sourceAnchor, 2);
    expect(b.displayBoundaryFor(1), 1);
    expect(b.displayBoundaryFor(999), 2);
    expect(b.displayBoundaryFor(-1), 0);
  });
  test('a source step missing from Flutter UI still counts', () {
    final events = [
      _e(1, 'USER_TURN_ACCEPTED', {'text': '用户'}),
      _e(2, 'TOOL_RESULT_RECORDED', {
        'toolName': 'provideSkillTemplate',
        'result': {
          'artifact': {
            'artifactId': 'a',
            'kind': 'TEXT',
            'fileName': 'a.txt',
            'mimeType': 'text/plain',
            'status': 'READY',
          },
        },
      }),
      _e(3, 'ASSISTANT_TURN_COMMITTED', {'text': '回复'}),
    ];
    final b = boundary(events);
    expect(b.sourceAnchor, 3);
    expect(b.displayBoundaryFor(2), 1);
    expect(b.displayBoundaryFor(3), 2);
  });
  test('call confirmation updates keep one step at original position', () {
    final events = [
      _tool(1, 'makeCall', 'call', {'phoneNumber': '+15555550100'}),
      _e(2, 'ASSISTANT_TURN_COMMITTED', {'text': '确认'}),
      _tool(3, 'makeCall', 'call', {
        'phoneNumber': '+15555550100',
        'primaryGoal': '更新',
      }),
    ];
    final steps = ConversationSourceSteps.project(events);
    expect(steps, hasLength(2));
    expect(steps.first.sequence, 1);
    expect(
      boundary(events).displayBoundaryFor(1),
      2,
      reason: 'the confirmation prompt belongs to the same tool source step',
    );
  });
  test('rejected call confirmation is removed before counting', () {
    final events = [
      _tool(1, 'makeCall', 'call', {'phoneNumber': '+15555550100'}),
      _e(2, 'TOOL_RESULT_RECORDED', {
        'toolName': 'makeCall',
        'toolCallId': 'call',
        'resultStatus': 'rejected',
      }),
    ];
    expect(boundary(events).sourceAnchor, 0);
  });
  test('document batch duplicates occupy one source boundary', () {
    final document = jsonEncode({
      'schema': 'user_document_batch.v1',
      'documentBatchId': 'd',
      'documents': [
        {'fileName': 'test.docx'},
      ],
    });
    final events = [
      _e(1, 'USER_TURN_ACCEPTED', {'inputKind': 'document', 'text': document}),
      _e(2, 'USER_TURN_ACCEPTED', {'inputKind': 'document', 'text': document}),
    ];
    expect(ConversationSourceSteps.project(events), hasLength(1));
    expect(boundary(events).sourceAnchor, 1);
  });
  test(
    'confirmed Batch Plus execution does not add a second confirmation step',
    () {
      final events = [
        _tool(1, 'confirmBatchTask', 'snapshot', {
          'snapshotJson': {'title': '合成'},
        }),
        _e(2, 'TOOL_RESULT_RECORDED', {
          'toolName': 'confirmBatchTask',
          'toolCallId': 'snapshot',
          'result': {'decision': 'CONFIRMED'},
        }),
        _tool(3, 'makeBatchCalls', 'execute', {
          'recipients': [
            {'targetName': 'A', 'phoneNumber': '+15555550100'},
          ],
        }),
      ];
      final steps = ConversationSourceSteps.project(events);
      expect(steps, hasLength(1));
      expect(steps.single.id, 'ledger:batch-confirmation:snapshot');
    },
  );
  test(
    'isolated confirmation result with no visible content is not trailing anchor',
    () {
      final events = [
        _e(1, 'USER_TURN_ACCEPTED', {'text': '用户'}),
        _e(2, 'TOOL_RESULT_RECORDED', {
          'toolName': 'confirmBatchTask',
          'toolCallId': 'orphan',
        }),
      ];
      expect(ConversationSourceSteps.project(events), hasLength(2));
      expect(boundary(events).sourceAnchor, 1);
    },
  );
  test(
    'one committed event with batch and text has two distinct display boundaries',
    () {
      final events = [
        _e(1, 'ASSISTANT_TURN_COMMITTED', {
          'text': '已汇总',
          'batchCallResult': {
            'batchId': 'b',
            'status': 'COMPLETED',
            'items': [
              {'itemId': 'one', 'targetName': 'A', 'attemptCount': 1},
            ],
          },
        }),
      ];
      expect(ConversationMessages.project(events), hasLength(2));
      final b = boundary(events);
      expect(b.sourceAnchor, 2);
      expect(b.displayBoundaryFor(1), 1);
      expect(b.displayBoundaryFor(2), 2);
    },
  );
  test(
    'unknown schema and recovery superseded model facts do not add steps',
    () {
      final events = [
        _e(1, 'USER_TURN_ACCEPTED', {'text': '旧'}, command: 'old'),
        _e(2, 'RUN_CANCELLED', {'stage': 'recovery_revision'}, command: 'old'),
        _e(3, 'ASSISTANT_TURN_COMMITTED', {'text': '未知'}, schema: 9),
        _e(4, 'USER_TURN_ACCEPTED', {'text': '新'}, command: 'new'),
      ];
      expect(boundary(events).sourceAnchor, 1);
    },
  );
  test(
    'uncommitted user precedes durable assistant and disappears on replacement',
    () {
      final events = [
        _e(1, 'ASSISTANT_TURN_COMMITTED', {'text': '回复'}, command: 'turn'),
      ];
      final visible = [
        const ConversationMessage(
          id: 'local:user',
          role: MessageRole.user,
          text: '用户',
          transient: true,
        ),
        ...ConversationMessages.project(events),
      ];
      final b = ConversationOcrBoundary.project(events, visible);
      expect(b.sourceAnchor, 2);
      expect(b.displayBoundaryFor(1), 1);
      expect(b.displayBoundaryFor(2), 2);
    },
  );
  test('empty user steps count while empty assistant facts do not', () {
    final events = [
      _e(1, 'USER_TURN_ACCEPTED', {'text': ''}),
      _e(2, 'ASSISTANT_TURN_COMMITTED', {'text': ''}),
    ];
    expect(boundary(events).sourceAnchor, 1);
    expect(boundary(events).displayBoundaryFor(1), 0);
  });
  test(
    'batch suppresses call step when task identity arrives after request',
    () {
      final events = [
        _e(1, 'CALL_REQUESTED', {}, attempt: 'a'),
        _e(2, 'CALL_STARTED', {}, attempt: 'a', task: 'b'),
        _e(3, 'ASSISTANT_TURN_COMMITTED', {
          'batchCallResult': {
            'batchId': 'b',
            'items': [
              {'itemId': 'one', 'attemptCount': 1},
            ],
          },
        }),
      ];
      final steps = ConversationSourceSteps.project(events);
      expect(steps.map((s) => s.id), ['ledger:batch:b']);
      expect(boundary(events).sourceAnchor, 1);
    },
  );
}

LedgerEvent _e(
  int n,
  String type,
  Map<String, Object?> payload, {
  int schema = 1,
  String? command,
  String? attempt,
  String? task,
}) => LedgerEvent(
  eventId: 'e$n',
  sessionId: 's',
  sequence: n,
  type: type,
  schemaVersion: schema,
  payload: payload,
  commandId: command,
  callAttemptId: attempt,
  taskId: task,
);
LedgerEvent _tool(int n, String name, String id, Map<String, Object?> args) =>
    _e(n, 'TOOL_REQUESTED', {
      'toolName': name,
      'toolCallId': id,
      'arguments': args,
      'displayPayloadVersion': 1,
    });
