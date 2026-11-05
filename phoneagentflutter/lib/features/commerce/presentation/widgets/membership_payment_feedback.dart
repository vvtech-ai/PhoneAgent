import 'package:flutter/material.dart';
import '../controller/purchase_state.dart';
import '../payment_attempt_feedback.dart';
import 'commerce_display_format.dart';
import 'commerce_widgets.dart';
import '../../domain/commerce_catalog.dart';
import 'membership_status_caption.dart';
import 'commerce_order_display.dart';

/// Membership result uses the confirmed order, not the purchase preview.
class MembershipPaymentFeedback extends StatelessWidget {
  const MembershipPaymentFeedback({
    super.key,
    required this.state,
    required this.upgrade,
    required this.onDone,
    required this.onQuery,
    this.currentMembership,
    this.availablePoints,
    this.snapshotFailed = false,
  });
  final PurchaseState state;
  final bool upgrade;
  final VoidCallback onDone, onQuery;
  final MembershipCurrent? currentMembership;
  final int? availablePoints;
  final bool snapshotFailed;

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            height: 1.5,
            color: Color(0xFF737984),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF202532),
            ),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final feedback = paymentAttemptFeedback(state, upgrade: upgrade);
    final order = state.order;
    final fulfillment = order?.membershipFulfillment;
    final membership = currentMembership;
    final activeLevel =
        membership?.activeEntitlement?.level ?? membership?.level;
    final activeMonths =
        membership?.activeEntitlement?.months ?? membership?.currentMonths;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            feedback.title,
            style: const TextStyle(
              fontSize: 21,
              height: 1.4,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 22),
          if (feedback.completed && order != null) ...[
            _row('已购买', orderProductLabel(order)),
            _row(
              '当前权益',
              membership == null
                  ? (snapshotFailed ? '暂时无法查询' : '查询中…')
                  : '${membershipName(activeLevel!)}会员${activeMonths == null ? '' : ' · ${membershipPeriodCaption(activeMonths)}'}',
            ),
            if (fulfillment != null) ...[
              _row(
                '本次积分',
                fulfillment.initialEntitlementState == 'QUEUED' &&
                        fulfillment.firstActivationGrantedPoints == null
                    ? '暂未发放'
                    : '+${displayPoints(fulfillment.firstActivationGrantedPoints ?? fulfillment.initialGrantedPoints)}积分',
              ),
            ],
            _row(
              '可用积分',
              availablePoints == null
                  ? (snapshotFailed ? '暂时无法查询' : '查询中…')
                  : '${displayPoints(availablePoints!)}积分',
            ),
          ],
          Text(
            feedback.completed &&
                    fulfillment?.actualPurchaseType == 'NEW' &&
                    fulfillment?.entitlementState == 'ACTIVE'
                ? '已到账积分永久有效。'
                : feedback.message,
            style: const TextStyle(
              fontSize: 13,
              height: 1.65,
              color: Color(0xFF68707C),
            ),
          ),
          const SizedBox(height: 16),
          if (feedback.completed && snapshotFailed)
            TextButton(onPressed: onQuery, child: const Text('重新查询权益与积分')),
          if (!feedback.completed && order?.canQueryPayment == true) ...[
            CommerceAction('查询支付结果', onPressed: onQuery, busy: state.busy),
            const SizedBox(height: 10),
          ],
          CommerceAction('返回会员页面', onPressed: onDone),
        ],
      ),
    );
  }
}
