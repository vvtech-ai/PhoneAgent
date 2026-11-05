import '../widgets/membership_plan_details_button.dart';
import 'package:flutter/material.dart';
import '../../domain/commerce_catalog.dart';
import '../controller/catalog_controller.dart';
import '../widgets/commerce_widgets.dart';
import '../widgets/membership_offer.dart';
import '../widgets/membership_balance_card.dart';
import '../widgets/membership_status_caption.dart';
import '../widgets/commerce_read_retry.dart';

class MembershipPage extends StatelessWidget {
  const MembershipPage({
    super.key,
    required this.state,
    required this.availablePoints,
    required this.heldPoints,
    required this.onBack,
    required this.onRefresh,
    required this.onPoints,
    required this.onOrders,
    required this.onLedger,
    required this.onBuy,
    required this.onLevel,
    required this.onMonths,
    required this.onSupport,
    required this.onRestore,
    this.onPending,
    this.pointsPerMinute,
    this.onReloadProducts,
    this.todayDailyGrantReceived = false,
    this.todayDailyGrantPoints = 0,
    this.onAgreement,
    this.onLegal,
    this.modelNames = const {},
    this.showRestore = false,
  });
  final CatalogState state;
  final bool showRestore;
  final Map<String, String> modelNames;
  final VoidCallback? onReloadProducts;
  final int? availablePoints, heldPoints;
  final int? pointsPerMinute;
  final bool todayDailyGrantReceived;
  final int todayDailyGrantPoints;
  final ValueChanged<bool>? onAgreement;
  final VoidCallback? onLegal;
  final VoidCallback onBack,
      onPoints,
      onOrders,
      onLedger,
      onBuy,
      onSupport,
      onRestore;
  final Future<void> Function() onRefresh;
  final VoidCallback? onPending;
  final ValueChanged<String> onLevel;
  final ValueChanged<int> onMonths;
  @override
  Widget build(BuildContext context) => CommerceScaffold(
    title: '会员与积分',
    onBack: onBack,
    action: TextButton(
      onPressed: onOrders,
      child: const Text(
        '订单与发票',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Color(0xFF5F646D),
        ),
      ),
    ),
    child: RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
        children: [
          MembershipBalanceCard(
            availablePoints: availablePoints,
            heldPoints: heldPoints,
            pointsPerMinute: pointsPerMinute,
            todayDailyGrantReceived: todayDailyGrantReceived,
            todayDailyGrantPoints: todayDailyGrantPoints,
            onPoints: state.visibleOffers('POINTS_PACK').isNotEmpty
                ? onPoints
                : null,
            onLedger: onLedger,
          ),
          if (state.loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            ),
          if (!state.loading) ...[
            if (state.membership != null)
              Row(
                children: [
                  Expanded(
                    child: MembershipStatusCaption(
                      membership: state.membership!,
                    ),
                  ),
                  MembershipPlanDetailsButton(membership: state.membership!),
                ],
              ),
            if (state.membership?.nextGrantAt != null)
              Text(
                '下次积分发放 ${commerceDate(state.membership!.nextGrantAt)}',
                style: const TextStyle(fontSize: 11, color: Color(0xFF858991)),
              ),
            for (final term in state.membership?.terms ?? <MembershipTerm>[])
              if (term.id != state.membership?.currentTermId &&
                  term.status == 'ACTIVE')
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '已购${membershipName(term.level)}期限 ${commerceDate(term.startsAt)} 至 ${commerceDate(term.endsAt)}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF1767CA),
                    ),
                  ),
                ),
            if (state.membership?.pendingOrderNo != null)
              TextButton(
                onPressed: onPending ?? onOrders,
                child: const Text('处理待购买事项'),
              ),
            if (state.membership?.expiresAt != null ||
                state.membership?.pendingOrderNo != null)
              const SizedBox(height: 12),
            if (state.catalog?.membershipEnabled != true) ...[
              if (state.membership != null)
                MembershipOffer(
                  modelNames: modelNames,
                  state: state,
                  readOnly: true,
                  onMonths: onMonths,
                  onBuy: onBuy,
                  onSupport: onSupport,
                ),
            ] else if (state.unconfigured)
              CommerceCard(
                child: Column(
                  children: [
                    const Text('会员与商品暂未配置'),
                    if (state.membership != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        '当前身份：${membershipName(state.membership!.level)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF858991),
                        ),
                      ),
                    ],
                  ],
                ),
              )
            else ...[
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: const Color(0xFFE9EBEF),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Row(
                  children: [
                    for (final level in membershipLevels)
                      Expanded(
                        child: InkWell(
                          onTap: () => onLevel(level),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: level == state.selectedLevel
                                  ? Colors.white
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(11),
                              boxShadow: level == state.selectedLevel
                                  ? const [
                                      BoxShadow(
                                        color: Color(0x140F172A),
                                        blurRadius: 8,
                                        offset: Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Text(
                              membershipName(level),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: level == state.selectedLevel
                                    ? const Color(0xFF17191D)
                                    : const Color(0xFF70747C),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              MembershipOffer(
                modelNames: modelNames,
                state: state,
                onReloadProducts: onReloadProducts,
                onAgreement: onAgreement,
                onLegal: onLegal,
                onMonths: onMonths,
                onBuy: onBuy,
                onSupport: onSupport,
              ),
              if (state.offers.isNotEmpty && !state.channelAvailable)
                const Text(
                  '当前支付渠道暂不可用',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Color(0xFF858991)),
                ),
            ],
          ],
          if (state.requiresPlatformProducts && showRestore)
            Center(
              child: TextButton(
                onPressed: onRestore,
                child: const Text('恢复购买'),
              ),
            ),
          if (state.error.isNotEmpty)
            CommerceReadRetry(error: state.error, onRetry: onRefresh),
        ],
      ),
    ),
  );
}
