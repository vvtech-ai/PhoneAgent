import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/receipts/call_receipt.dart';
import 'package:phone_agent/features/conversation/domain/receipts/call_receipt_status.dart';
import 'package:phone_agent/features/conversation/domain/receipts/call_dialogue.dart';

void main() {
  CallReceipt receipt(
    String status, {
    String detail = '',
    Map<String, String> metadata = const {},
  }) => CallReceipt(
    attemptId: 'synthetic',
    status: status,
    detail: detail,
    metadata: metadata,
  );

  test('physical completion alone never proves business success', () {
    for (final status in [
      'COMPLETED',
      'CALL_COMPLETED',
      'SUCCESS',
      'DONE',
      'future',
    ]) {
      expect(
        CallReceiptStatus.outcome(receipt(status)),
        CallReceiptOutcome.unclear,
      );
      expect(CallReceiptStatus.label(receipt(status)), '结果未确认');
    }
    expect(
      CallReceiptStatus.outcome(receipt('CALL_STARTED')),
      CallReceiptOutcome.running,
    );
    expect(
      CallReceiptStatus.outcome(receipt('COMPLETED', detail: '餐厅无空位')),
      CallReceiptOutcome.failed,
    );
  });
  test('server execution error is a terminal failure label', () {
    final result = receipt('EXECUTION_ERROR', detail: '本次任务已结束，结果处理异常');
    expect(CallReceiptStatus.outcome(result), CallReceiptOutcome.failed);
    expect(CallReceiptStatus.label(result), '执行异常');
  });
  test('semantic evidence overrides physical state and result code', () {
    for (final key in [
      'agentOutcome',
      'reportCallOutcome',
      'callOutcome',
      'outcome',
      'agent_outcome',
    ]) {
      expect(
        CallReceiptStatus.outcome(
          receipt('FAILED', metadata: {key: 'SUCCESS'}),
        ),
        CallReceiptOutcome.completed,
      );
    }
    expect(
      CallReceiptStatus.outcome(
        receipt(
          'COMPLETED',
          metadata: {
            'agentOutcome': 'FAILED',
            'resultCode': 'SUCCESS_CONFIRMED',
          },
        ),
      ),
      CallReceiptOutcome.failed,
    );
    expect(
      CallReceiptStatus.outcome(
        receipt('COMPLETED', metadata: {'resultCode': 'SUCCESS_CONFIRMED'}),
      ),
      CallReceiptOutcome.completed,
    );
    expect(
      CallReceiptStatus.outcome(
        receipt('COMPLETED', metadata: {'resultCode': 'NO_ANSWER'}),
      ),
      CallReceiptOutcome.failed,
    );
    expect(
      CallReceiptStatus.outcome(receipt('CALL_CANCELLED')),
      CallReceiptOutcome.cancelled,
    );
  });
  test(
    'business failure stays distinct from technical error and insufficient points',
    () {
      expect(
        CallReceiptStatus.label(receipt('FAILED', detail: '连接失败')),
        '执行异常',
      );
      expect(
        CallReceiptStatus.label(
          receipt(
            'FAILED',
            detail: '连接失败',
            metadata: {'agentOutcome': 'FAILED'},
          ),
        ),
        '未完成',
      );
      expect(
        CallReceiptStatus.label(
          receipt(
            'FAILED',
            metadata: {'resultCode': 'POINTS_INSUFFICIENT_BALANCE'},
          ),
        ),
        '积分不足',
      );
    },
  );
  test(
    'dialogue roles, colon variants and repetitions follow current Android',
    () {
      final lines = CallDialogue.parse(
        '【AI】：你好\n商家: 您好\nAI: 你好\n预订结果：完成\nunknown: omitted\n[merchant]:可以：三位\nAI: ',
      );
      expect(lines.map((e) => e.text), ['你好', '您好', '你好', '可以：三位']);
      expect(lines.map((e) => e.role), [
        CallDialogueRole.assistant,
        CallDialogueRole.remote,
        CallDialogueRole.assistant,
        CallDialogueRole.remote,
      ]);
    },
  );
  test(
    'receipt parsing keeps metadata/dialogue fallback and rate without fabricated zeroes',
    () {
      final data = CallReceipt.fromResult({
        'status': 'COMPLETED',
        'metadata': {'dialogueDetail': 'AI：合成', 'agentOutcome': 'SUCCESS'},
        'billingSummary': {
          'billingSessionId': 'b',
          'firstMinutePoints': 5,
          'blockDurationMs': 10000,
          'blockPoints': 1,
          'chargedPoints': -1,
        },
      });
      expect(data.transcript, 'AI：合成');
      expect(CallReceiptStatus.outcome(data), CallReceiptOutcome.completed);
      expect(data.billing!.firstMinutePoints, 5);
      expect(data.billing!.blockDurationMs, 10000);
      expect(data.billing!.blockPoints, 1);
      expect(data.billing!.chargedPoints, isNull);
      expect(data.billing!.remainingPoints, isNull);
      expect(
        () => data.metadata['agentOutcome'] = 'FAILED',
        throwsUnsupportedError,
      );
      expect(ReceiptBilling.parse({'chargedPoints': 5}), isNull);
    },
  );
}
