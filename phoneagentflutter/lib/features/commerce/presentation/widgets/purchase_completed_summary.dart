import '../membership_result_feedback.dart';
import 'package:flutter/material.dart';
import '../../domain/commerce_order.dart';
import '../order_payment_amount.dart';
import '../invoice_availability_notice.dart';
import 'commerce_widgets.dart';
import 'commerce_order_display.dart';
import 'commerce_support_contact.dart';

class PurchaseCompletedSummary extends StatelessWidget {
  const PurchaseCompletedSummary({
    super.key,
    required this.order,
    required this.onDone,
    required this.onSupport,
    this.supportEmail,
  });
  final CommerceOrder order;
  final String? supportEmail;
  final VoidCallback onDone, onSupport;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 28, 12, 28),
        child: Column(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: const BoxDecoration(
                color: Color(0xFFE8F8EF),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check,
                size: 28,
                color: Color(0xFF199257),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              membershipResultFeedback(order)?.title ?? '支付成功',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            Text(
              orderProductLabel(order),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Color(0xFF777B84)),
            ),
            if (membershipResultFeedback(order) case final feedback?) ...[
              const SizedBox(height: 8),
              Text(
                feedback.message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Color(0xFF777C84)),
              ),
            ],
            if (order.effectiveAt != null) ...[
              const SizedBox(height: 8),
              Text(
                '${order.membershipFulfillment != null
                    ? '权益生效'
                    : order.effectiveAt!.isAfter(DateTime.now())
                    ? '已购买，待生效'
                    : '权益生效'} ${commerceDate(order.effectiveAt)}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF1767CA)),
              ),
            ],
          ],
        ),
      ),
      CommerceAction('完成', onPressed: onDone),
      const SizedBox(height: 12),
      ExpansionTile(
        title: const Text('订单详情', style: TextStyle(fontSize: 13)),
        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        children: [
          _detail('支付状态', orderListStateLabel(order)),
          _detail('原订单', order.orderNo),
          _detail('商品', orderProductLabel(order)),
          _detail('订单金额', orderPaymentAmount(order)),
          _detail('实付金额', orderPaymentAmount(order, paid: true)),
        ],
      ),
      CommerceSupportContact(email: supportEmail, onContact: onSupport),
      if (invoiceAvailabilityNotice(order).isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(
            invoiceAvailabilityNotice(order),
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF656A73),
              height: 1.5,
            ),
          ),
        ),
    ],
  );

  Widget _detail(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF777C84)),
          ),
        ),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 12))),
      ],
    ),
  );
}
