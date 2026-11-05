import 'package:flutter/material.dart';
import '../../domain/commerce_order.dart';

class CommerceOrderAction extends StatelessWidget {
  const CommerceOrderAction({
    super.key,
    required this.order,
    required this.onOrder,
    required this.onInvoice,
    this.invoiceStatus,
  });
  final CommerceOrder order;
  final VoidCallback onOrder, onInvoice;
  final String? invoiceStatus;

  @override
  Widget build(BuildContext context) {
    final viewOrder = order.unresolved || order.paymentState != 'SUCCEEDED';
    final invoicing = !viewOrder && invoiceStatus == 'INVOICING';
    final label = viewOrder
        ? '查看订单'
        : switch (invoiceStatus) {
            'INVOICING' => '开票中',
            'ISSUED' => '已开票',
            'FAILED' => '开票失败',
            _ => order.invoiceAllowed ? '开发票' : '开票说明',
          };
    final color = invoicing
        ? const Color(0xFF9A6B00)
        : !viewOrder && invoiceStatus == 'FAILED'
        ? const Color(0xFFB42318)
        : const Color(0xFF1677FF);
    return TextButton(
      onPressed: invoicing
          ? null
          : viewOrder
          ? onOrder
          : onInvoice,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}
