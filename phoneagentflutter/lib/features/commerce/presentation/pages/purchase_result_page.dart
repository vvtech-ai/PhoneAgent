import 'package:flutter/material.dart';
import '../../domain/commerce_catalog.dart';
import '../../domain/commerce_order.dart';
import '../controller/purchase_controller.dart';
import '../payment_attempt_feedback.dart';
import '../order_payment_amount.dart';
import '../invoice_availability_notice.dart';
import '../widgets/commerce_widgets.dart';
import '../widgets/commerce_order_display.dart';
import '../widgets/purchase_completed_summary.dart';
import '../widgets/commerce_support_contact.dart';

class PurchaseResultPage extends StatelessWidget {
  const PurchaseResultPage({
    super.key,
    required this.state,
    required this.onBack,
    required this.onQuery,
    required this.onPay,
    required this.onClose,
    required this.onRecovery,
    required this.onConfirmRecovery,
    required this.onSupport,
    required this.onDone,
    this.paymentAvailable = true,
    this.supportEmail,
  });
  final PurchaseState state;
  final bool paymentAvailable;
  final String? supportEmail;
  final VoidCallback onBack,
      onQuery,
      onPay,
      onClose,
      onRecovery,
      onConfirmRecovery,
      onSupport,
      onDone;
  Widget _row(String label, String value) => Padding(
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
  @override
  Widget build(BuildContext context) {
    final order = state.order;
    final recovery = state.recovery;
    return CommerceScaffold(
      title: '购买结果',
      onBack: onBack,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (order == null && !state.busy && state.error.isEmpty)
            const CommerceCard(child: Text('暂无待恢复订单')),
          if (order == null && state.busy)
            const Center(child: CircularProgressIndicator()),
          if (order?.appState == OrderAppState.completed)
            PurchaseCompletedSummary(
              order: order!,
              onDone: onDone,
              onSupport: onSupport,
              supportEmail: supportEmail,
            ),
          if (order != null && order.appState != OrderAppState.completed)
            CommerceCard(
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  const Icon(
                    Icons.info_outline,
                    size: 58,
                    color: Color(0xFF1677FF),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    orderListStateLabel(order),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  if (order.appState == OrderAppState.crediting)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Text('已支付，权益处理中'),
                    ),
                  if (state.nativeResultStatus != null &&
                      order.paymentState != 'SUCCEEDED')
                    _row('本次支付', paymentAttemptFeedback(state).title),
                  if (order.appleFlowExpired)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(paymentAttemptFeedback(state).message),
                    ),
                  _row('原订单', order.orderNo),
                  _row('商品', orderProductLabel(order)),
                  _row('订单金额', orderPaymentAmount(order)),
                  if (order.cashPaidFen > 0 ||
                      order.platformPaidAmountMilliunits != null)
                    _row('实付金额', orderPaymentAmount(order, paid: true)),
                  if (order.effectiveAt != null)
                    _row('权益生效', commerceDate(order.effectiveAt)),
                  if (state.busy)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: LinearProgressIndicator(),
                    ),
                  if (order.canRequestPaymentRetry && paymentAvailable) ...[
                    CommerceAction(
                      order.channel == 'ALIPAY' ? '重新支付' : '继续支付',
                      onPressed: state.busy ? null : onPay,
                    ),
                  ],
                  if (order.canRequestClose) ...[
                    const SizedBox(height: 8),
                    CommerceAction(
                      '请求关闭订单',
                      secondary: true,
                      onPressed: state.busy ? null : onClose,
                    ),
                  ],
                  if (order.canQueryPayment) ...[
                    const SizedBox(height: 8),
                    CommerceAction(
                      '查询原订单',
                      secondary: true,
                      onPressed: state.busy ? null : onQuery,
                    ),
                  ],
                  if (order.recoveryRequired) ...[
                    const SizedBox(height: 8),
                    CommerceAction(
                      '查看恢复方案',
                      onPressed: state.busy ? null : onRecovery,
                    ),
                  ],
                  CommerceSupportContact(
                    email: supportEmail,
                    onContact: onSupport,
                  ),
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
              ),
            ),
          if (recovery != null)
            CommerceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '确认恢复原订单',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  _row('原订单', recovery.orderNo),
                  _row('已付金额', recoveryPaymentAmount(recovery)),
                  _row('目标等级', membershipName(recovery.targetLevel)),
                  _row(
                    '定价依据',
                    '${recovery.pricingOrderNo}\n${money(recovery.targetPriceFen)} / ${periodName(recovery.targetMonths)}',
                  ),
                  _row(
                    '追加时长',
                    '${(recovery.appendSeconds / 86400).toStringAsFixed(2)} 天（${recovery.appendSeconds} 秒）',
                  ),
                  _row('追加起点', commerceDate(recovery.appendStartsAt)),
                  _row('预计到期', commerceDate(recovery.estimatedExpiresAt)),
                  _row('方案有效期', commerceDateTime(recovery.expiresAt)),
                  const Text(
                    '确认后只追加会员期限，不再次付款；追加期限开始后发放对应积分。',
                    style: TextStyle(fontSize: 12, color: Color(0xFF777C84)),
                  ),
                  const SizedBox(height: 12),
                  CommerceAction(
                    '本人确认恢复',
                    onPressed: state.busy ? null : onConfirmRecovery,
                  ),
                ],
              ),
            ),
          if (state.error.isNotEmpty)
            Text(
              state.error,
              style: const TextStyle(color: Color(0xFFD33A3A)),
              textAlign: TextAlign.center,
            ),
        ],
      ),
    );
  }
}
