import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/receipts/batch_receipt.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/call_receipt_phone_mask.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/call_receipt_text.dart';

void main() {
  test('masks two numbers separately and leaves nearby time intact', () {
    expect(
      maskCallReceiptPhoneNumbers('两个号码 13800002222、13900001111，2点回拨'),
      '两个号码 尾号 2222、尾号 1111，2点回拨',
    );
  });

  test('does not mask short numeric business details', () {
    expect(
      maskCallReceiptPhoneNumbers('10月27日，14:30，4人，100元'),
      '10月27日，14:30，4人，100元',
    );
    expect(maskCallReceiptPhoneNumbers('已打断…'), '已打断…');
  });

  test(
    'masks numbers separated by ordinary speech pauses and extra spaces',
    () {
      expect(
        maskCallReceiptPhoneNumbers('电话一、三、八、零、零、零、零、二、二、二、二'),
        '电话尾号 2222',
      );
      expect(maskCallReceiptPhoneNumbers('138  0000  2222'), '尾号 2222');
      expect(maskCallReceiptPhoneNumbers('号码幺三八0000二二二二'), '号码尾号 2222');
    },
  );

  test(
    'batch plain text masks field and transcript without changing receipt values',
    () {
      final receipt = BatchReceipt.fromJson({
        'batchId': 'privacy-batch',
        'status': 'FINISHED',
        'items': [
          {
            'itemId': 'first',
            'phoneNumber': '13800002222',
            'status': 'SUCCESS',
            'transcript': 'AI：请回拨一三八零零零零二二二二',
            'receiptFields': [
              {'key': 'phone', 'label': '手机', 'value': '13800002222'},
            ],
          },
        ],
      }, fallbackId: 'privacy-batch');
      final text = CallReceiptText.formatBatch(receipt);
      expect(text, contains('尾号 2222'));
      expect(text, isNot(contains('13800002222')));
      expect(text, isNot(contains('一三八零零零零二二二二')));
      expect(receipt.items.single.phoneNumber, '13800002222');
    },
  );
}
