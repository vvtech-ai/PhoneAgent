import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/receipts/call_receipt.dart';
import 'package:phone_agent/features/conversation/domain/receipts/call_receipt_status.dart';
import 'package:phone_agent/features/conversation/domain/receipts/native_call_receipt_presentation.dart';

void main() {
  test(
    'explicit no reservation result is completed and distinct from booking success',
    () {
      final receipt = CallReceipt.fromResult({
        'callAttemptId': 'synthetic',
        'status': 'COMPLETED',
        'detail': '商家表示无需登记预订信息',
        'metadata': {
          'resultCode': 'NO_RESERVATION_REQUIRED',
          'sceneType': 'FOOD_ORDERING',
        },
      });
      final plan = NativeCallReceiptPresentation(receipt);
      expect(plan.outcome, CallReceiptOutcome.completed);
      expect(plan.title, '任务完成');
      expect(plan.status, '无需预订，可直接到店');
      final booking = CallReceipt(
        attemptId: 'booked',
        status: 'COMPLETED',
        metadata: {
          'resultCode': 'SUCCESS_CONFIRMED',
          'sceneType': 'FOOD_ORDERING',
        },
      );
      expect(NativeCallReceiptPresentation(booking).status, '✓任务完成');
    },
  );
  test('free text does not fabricate a successful outcome', () {
    final receipt = CallReceipt(
      attemptId: 'unknown',
      status: 'COMPLETED',
      detail: '是否可以直接到店尚不明确',
    );
    expect(CallReceiptStatus.outcome(receipt), CallReceiptOutcome.unclear);
  });
}
