import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/conversation_messages.dart';
import 'package:phone_agent/features/conversation/domain/conversation_result_observation.dart';
import 'package:phone_agent/features/conversation/domain/receipts/batch_receipt.dart';
import 'package:phone_agent/features/conversation/domain/receipts/call_receipt.dart';
import 'package:phone_agent/features/conversation/domain/receipts/receipt_message_mapper.dart';

void main() {
  const identity = ConversationResultIdentity(
    sessionId: 'session',
    taskId: 'task',
    callAttemptId: 'attempt',
    generation: 4,
  );

  ConversationMessage call(
    String status, {
    String outcome = 'SUCCESS',
    Map<String, String>? metadata,
  }) => ConversationMessage(
    id: 'call',
    role: MessageRole.assistant,
    text: '',
    receipt: CallReceipt(
      attemptId: 'attempt',
      callId: 'call',
      status: status,
      metadata: metadata ?? {'agentOutcome': outcome},
    ),
  );

  test('physical end without a durable outcome stays pending', () {
    final result = ConversationResultObservation.evaluate(
      const [],
      identity: identity,
      callId: 'call',
      physicalEnd: ConversationPhysicalEnd.transportFailure,
    );
    expect(result.kind, ConversationResultKind.pending);
    expect(result.confirmed, isFalse);
  });

  test('final unclear response closes without duplicate agent outcome', () {
    final result = ConversationResultObservation.evaluate(
      ReceiptMessageMapper.fromFinal({
        'callResult': {
          'callAttemptId': 'attempt',
          'callId': 'call',
          'status': 'UNCLEAR',
          'headline': '预订未获确认',
        },
      }, 'confirmation-command'),
      identity: identity,
      callId: 'call',
    );
    expect(result.kind, ConversationResultKind.businessFailure);
    expect(result.confirmed, isTrue);
  });

  test('physical closure without semantic report cannot confirm a result', () {
    for (final status in ['CALL_COMPLETED', 'COMPLETED']) {
      final result = ConversationResultObservation.evaluate(
        [
          ConversationMessage(
            id: 'physical-$status',
            role: MessageRole.assistant,
            text: '',
            receipt: CallReceipt(
              attemptId: 'attempt',
              callId: 'call',
              status: status,
            ),
          ),
        ],
        identity: identity,
        callId: 'call',
        physicalEnd: ConversationPhysicalEnd.hangup,
      );
      expect(result.kind, ConversationResultKind.pending, reason: status);
      expect(result.confirmed, isFalse, reason: status);
    }
  });

  test('physical-only marker cannot confirm a copied semantic outcome', () {
    final result = ConversationResultObservation.evaluate(
      [
        call(
          'COMPLETED',
          metadata: {'physicalTerminalOnly': 'true', 'agentOutcome': 'SUCCESS'},
        ),
      ],
      identity: identity,
      callId: 'call',
      physicalEnd: ConversationPhysicalEnd.hangup,
    );
    expect(result.kind, ConversationResultKind.pending);
  });

  test('pending or unknown agent outcome cannot confirm a result', () {
    for (final outcome in ['PENDING', 'UNKNOWN']) {
      final result = ConversationResultObservation.evaluate(
        [
          call(
            'COMPLETED',
            metadata: {
              'agentOutcome': outcome,
              'resultCode': 'SUCCESS_CONFIRMED',
            },
          ),
        ],
        identity: identity,
        callId: 'call',
        physicalEnd: ConversationPhysicalEnd.hangup,
      );
      expect(result.kind, ConversationResultKind.pending, reason: outcome);
      expect(result.confirmed, isFalse, reason: outcome);
    }
  });

  test('semantic aliases and committed failed status remain failures', () {
    for (final key in [
      'reportCallOutcome',
      'callOutcome',
      'outcome',
      'agent_outcome',
    ]) {
      final result = ConversationResultObservation.evaluate(
        [
          call(
            'COMPLETED',
            metadata: {key: 'FAILED', 'resultCode': 'SUCCESS_CONFIRMED'},
          ),
        ],
        identity: identity,
        callId: 'call',
      );
      expect(result.kind, ConversationResultKind.businessFailure, reason: key);
    }
    final committed = ConversationResultObservation.evaluate(
      [call('FAILED', metadata: const {})],
      identity: identity,
      callId: 'call',
    );
    expect(committed.kind, ConversationResultKind.businessFailure);
  });

  test('late completed receipt is business success', () {
    final result = ConversationResultObservation.evaluate(
      [call('COMPLETED')],
      identity: identity,
      callId: 'call',
      physicalEnd: ConversationPhysicalEnd.hangup,
    );
    expect(result.kind, ConversationResultKind.businessSuccess);
  });

  test(
    'execution error ends observation without deciding business outcome',
    () {
      final result = ConversationResultObservation.evaluate(
        [
          ConversationMessage(
            id: 'execution-error',
            role: MessageRole.assistant,
            text: '',
            receipt: CallReceipt(
              attemptId: 'attempt',
              callId: 'call',
              status: 'EXECUTION_ERROR',
              detail: '本次任务已结束，结果处理异常',
            ),
          ),
        ],
        identity: identity,
        callId: 'call',
        physicalEnd: ConversationPhysicalEnd.hangup,
      );
      expect(result.kind.name, 'executionError');
      expect(result.confirmed, isTrue);
    },
  );

  test('committed batch execution error closes despite stale route status', () {
    ConversationMessage batch(String routeStatus) => ConversationMessage(
      id: 'batch',
      role: MessageRole.assistant,
      text: '',
      transient: false,
      batchReceipt: BatchReceipt.fromJson({
        'batchId': 'batch',
        'status': 'RUNNING',
        'executionStatus': 'EXECUTION_ERROR',
        'items': [
          {'itemId': 'first', 'status': 'FAILED'},
          {'itemId': 'second', 'status': routeStatus},
        ],
      }, fallbackId: 'batch'),
    );

    for (final status in ['CALLING', 'RINGING', 'CONNECTED', 'ENDING']) {
      final committed = ConversationResultObservation.evaluate(
        [batch(status)],
        identity: identity,
        batchId: 'batch',
        physicalEnd: ConversationPhysicalEnd.terminal,
      );
      expect(
        committed.kind,
        ConversationResultKind.executionError,
        reason: status,
      );
    }
    final ended = ConversationResultObservation.evaluate(
      [batch('UNCLEAR')],
      identity: identity,
      batchId: 'batch',
    );
    expect(ended.kind.name, 'executionError');
    expect(ended.confirmed, isTrue);
  });
  test(
    'reconciled batch is final while its business result is unavailable',
    () {
      final receipt = BatchReceipt.fromJson({
        'batchId': 'batch',
        'status': 'INCOMPLETE',
        'executionStatus': 'FINISHED',
        'resultCode': 'BUSINESS_RESULT_UNAVAILABLE',
        'items': [
          {'itemId': 'first', 'status': 'UNCLEAR'},
        ],
      }, fallbackId: 'batch');
      final observed = ConversationResultObservation.evaluate(
        [
          ConversationMessage(
            id: 'batch',
            role: MessageRole.assistant,
            text: '',
            batchReceipt: receipt,
          ),
        ],
        identity: identity,
        batchId: 'batch',
      );
      expect(observed.kind.name, 'businessUnavailable');
      expect(observed.confirmed, isTrue);
      expect(observed.reason, 'BUSINESS_RESULT_UNAVAILABLE');
    },
  );

  test('structured failure and points rejection never become success', () {
    expect(
      ConversationResultObservation.evaluate(
        [call('FAILED', outcome: 'CALL_FAILED')],
        identity: identity,
        callId: 'call',
      ).kind,
      ConversationResultKind.businessFailure,
    );
    final batch = BatchReceipt.fromJson({
      'batchId': 'batch',
      'status': 'FAILED',
      'resultCode': 'POINTS_INSUFFICIENT_BALANCE',
      'items': [
        {'itemId': '1', 'status': 'FAILED', 'attemptCount': 0},
      ],
    }, fallbackId: 'batch');
    expect(
      ConversationResultObservation.evaluate(
        [
          ConversationMessage(
            id: 'batch',
            role: MessageRole.assistant,
            text: '',
            batchReceipt: batch,
          ),
        ],
        identity: identity,
        batchId: 'batch',
      ).kind,
      ConversationResultKind.businessFailure,
    );
  });

  test('identity key keeps generation and stable IDs separate', () {
    expect(identity.key, 'session|task|attempt|4');
    expect(
      const ConversationResultIdentity(
        sessionId: 'session',
        taskId: 'task',
        callAttemptId: 'attempt',
        generation: 5,
      ).key,
      isNot(identity.key),
    );
  });

  test('gate rejects old generations and duplicate confirmed results', () {
    final gate = ConversationResultGate();
    final result = ConversationResultObservation.evaluate(
      [call('COMPLETED')],
      identity: identity,
      callId: 'call',
    );
    expect(gate.accept(result, currentGeneration: 4), isTrue);
    expect(gate.accept(result, currentGeneration: 4), isFalse);
    expect(gate.accept(result, currentGeneration: 5), isFalse);
  });
}
