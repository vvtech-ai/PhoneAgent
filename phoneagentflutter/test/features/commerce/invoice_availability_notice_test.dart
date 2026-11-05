import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/commerce/data/commerce_dto.dart';
import 'package:phone_agent/features/commerce/presentation/invoice_availability_notice.dart';
import 'commerce_dto_test.dart' show orderJson;

void main() {
  for (final entry in {
    'PENDING': 'PENDING_PAYMENT',
    'PROCESSING': 'PAYING',
    'FAILED': 'PAYMENT_FAILED',
    'CANCELED': 'CANCELED',
    'CLOSED': 'CLOSED',
  }.entries) {
    test(
      '${entry.key} explains actual unpaid state without claiming refund',
      () {
        final order = CommerceDto.order({
          ...orderJson(),
          'invoiceAllowed': false,
          'paymentState': entry.key,
          'fulfillmentState': 'NOT_STARTED',
          'appState': entry.value,
          'cashPaidFen': 0,
        });
        final notice = invoiceAvailabilityNotice(order);
        expect(
          notice,
          entry.key == 'CANCELED' || entry.key == 'CLOSED'
              ? '该订单已取消或关闭，无法申请开票'
              : '该订单尚未支付成功，支付成功后可查看开票资格',
        );
        expect(notice, isNot(contains('退款')));
      },
    );
  }
  test(
    'unknown ineligibility with paid cash never invents refund or issued status',
    () {
      final notice = invoiceAvailabilityNotice(
        CommerceDto.order({...orderJson(), 'invoiceAllowed': false}),
      );
      expect(notice, '当前订单无法发起新的开票申请，请查询已有发票或联系售后');
      expect(notice, isNot(contains('已退款')));
      expect(notice, isNot(contains('已开票')));
    },
  );
  test('eligible Apple CNY and Alipay have no restriction notice', () {
    for (final channel in ['APPLE_IAP', 'ALIPAY']) {
      final order = CommerceDto.order({
        ...orderJson(),
        'channel': channel,
        'invoiceAllowed': true,
      });
      expect(invoiceAvailabilityNotice(order), isEmpty);
    }
  });
  test(
    'unknown Apple receipt does not mistake accounting zero for free purchase',
    () {
      final order = CommerceDto.order({
        ...orderJson(),
        'channel': 'APPLE_IAP',
        'invoiceAllowed': false,
        'cashPaidFen': 0,
        'platformPaidCurrency': null,
        'platformPaidAmountMilliunits': null,
      });
      expect(invoiceAvailabilityNotice(order), '暂无法确认该订单的开票资格，请联系售后协助处理');
    },
  );
}
