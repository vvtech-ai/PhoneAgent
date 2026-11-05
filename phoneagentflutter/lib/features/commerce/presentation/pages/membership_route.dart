import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/commerce_providers.dart';
import '../../../../app/apple_restore_providers.dart';
import '../../../../app/membership_model_names_provider.dart';
import '../../../../app/business_providers.dart';
import '../../../../app/points_providers.dart';
import '../../../../core/design/native_notice.dart';
import '../../data/device_commerce_legal_document.dart';
import '../../domain/commerce_catalog.dart';
import '../../../points/presentation/pages/points_wallet_route.dart';
import '../widgets/points_confirmation_sheet.dart';
import '../widgets/membership_confirmation_sheet.dart';
import '../widgets/purchase_feedback_host.dart';
import '../widgets/purchase_loading_overlay.dart';
import '../widgets/pending_membership_purchase_sheet.dart';
import '../controller/membership_checkout.dart';
import '../membership_card_presentation.dart';
import 'membership_page.dart';
import 'points_purchase_page.dart';
import 'commerce_orders_route.dart';
import 'purchase_result_route.dart';

class MembershipRoute extends ConsumerStatefulWidget {
  const MembershipRoute({super.key});
  @override
  ConsumerState<MembershipRoute> createState() => _MembershipRouteState();
}

class _MembershipRouteState extends ConsumerState<MembershipRoute>
    with WidgetsBindingObserver {
  bool _checkoutActive = false;
  bool _pendingActive = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final order = ref.read(purchaseControllerProvider).order;
      if (order != null) {
        ref.read(purchaseControllerProvider.notifier).query(order.orderNo);
      }
    }
  }

  Future<void> _push(Widget page) => Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => UncontrolledProviderScope(
        container: ProviderScope.containerOf(context),
        child: page,
      ),
    ),
  );
  Future<void> _legal() async {
    final catalog = ref.read(catalogControllerProvider).catalog;
    if (catalog == null) return;
    try {
      await const DeviceCommerceLegalDocument().open(catalog.agreementUrl);
    } catch (_) {
      if (mounted) showNativeNotice(context, '暂时无法打开付费协议，请重试');
    }
  }

  Future<void> _buy(
    ProductOffer product, {
    BuildContext? purchaseContext,
  }) async {
    if (_checkoutActive || _pendingActive) return;
    final owner = purchaseContext ?? context;
    final ownerRoute = ModalRoute.of(owner);
    final state = ref.read(catalogControllerProvider);
    final catalog = state.catalog;
    if (catalog == null) return;
    final epoch = ref.read(loginEpochProvider);
    final controller = ref.read(purchaseControllerProvider.notifier);
    final existing = controller.snapshot.order;
    final pendingOrderNo =
        state.membership?.pendingOrderNo ??
        (existing?.productType == 'MEMBERSHIP' && existing?.unresolved == true
            ? existing?.orderNo
            : null);
    if (product.productType == 'MEMBERSHIP' && pendingOrderNo != null) {
      await _pending(pendingOrderNo);
      return;
    }
    bool current() =>
        mounted &&
        owner.mounted &&
        ownerRoute?.isCurrent != false &&
        ref.read(catalogControllerProvider).purchaseEnabled(product) &&
        epoch == ref.read(loginEpochProvider);
    _checkoutActive = true;
    try {
      final checkout = MembershipCheckout(controller);
      final outcome = await checkout.buy(
        product,
        state,
        isCurrent: current,
        confirm: (quote) async {
          if (product.productType == 'MEMBERSHIP') {
            return await showDialog<bool>(
                  context: owner,
                  builder: (sheet) => MembershipConfirmationSheet(
                    quote: quote,
                    productName: membershipPlanLabel(
                      level: product.level,
                      months: product.months,
                    ),
                    displayPrice: state.requiresPlatformProducts
                        ? state.price(product)
                        : money(quote.cashAmountFen, currency: quote.currency),
                    apple: state.requiresPlatformProducts,
                    paymentAvailable: state.purchasable(product),
                    agreementAccepted: state.agreementAccepted,
                    onConfirm: () => Navigator.pop(sheet, true),
                  ),
                ) ==
                true;
          }
          return await showModalBottomSheet<bool>(
                context: owner,
                isScrollControlled: true,
                backgroundColor: Colors.white,
                builder: (sheet) => PointsConfirmationSheet(
                  product: product,
                  displayPrice: state.requiresPlatformProducts
                      ? state.price(product)
                      : money(quote.cashAmountFen, currency: quote.currency),
                  apple: state.requiresPlatformProducts,
                  onConfirm: () => Navigator.pop(sheet, true),
                ),
              ) ==
              true;
        },
      );
      if (!owner.mounted || !current()) return;
      if (outcome == CheckoutOutcome.error) {
        final error = controller.snapshot.error;
        if (state.requiresPlatformProducts && error != '请先阅读并同意付费协议') {
          await ref.read(catalogControllerProvider.notifier).load();
          if (!owner.mounted || !current()) return;
        }
        if (!owner.mounted) return;
        showNativeNotice(
          owner,
          error.isNotEmpty ? error : '当前价格或会员状态已更新，请刷新后重试',
        );
      } else if (outcome == CheckoutOutcome.purchase) {
        final orderNo = controller.snapshot.order!.orderNo;
        if (product.productType == 'MEMBERSHIP') {
          await showDialog<void>(
            context: owner,
            builder: (_) => Dialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              insetPadding: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              child: SizedBox(
                width: 360,
                child: PurchaseFeedbackHost(
                  orderNo: orderNo,
                  upgrade: checkout.upgrade,
                  membership: true,
                ),
              ),
            ),
          );
        } else {
          await showModalBottomSheet<void>(
            context: owner,
            isScrollControlled: true,
            backgroundColor: Colors.white,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            builder: (_) => PurchaseFeedbackHost(
              orderNo: orderNo,
              upgrade: checkout.upgrade,
            ),
          );
        }
        if (!current()) return;
        if (current()) {
          await Future.wait([
            ref.read(catalogControllerProvider.notifier).load(),
            ref.read(pointsWalletControllerProvider.notifier).refresh(),
          ]);
        }
      }
    } finally {
      _checkoutActive = false;
    }
  }

  Future<void> _ledger() => _push(const PointsWalletRoute(ledger: true));
  Future<void> _refreshMembership({String? orderNo}) async {
    final epoch = ref.read(loginEpochProvider);
    final purchase = ref.read(purchaseControllerProvider.notifier);
    final original = orderNo ?? purchase.snapshot.order?.orderNo;
    if (original != null) await purchase.query(original);
    if (!mounted || epoch != ref.read(loginEpochProvider)) return;
    await Future.wait([
      ref.read(catalogControllerProvider.notifier).load(),
      ref.read(pointsWalletControllerProvider.notifier).refresh(),
    ]);
  }

  Future<void> _pending(String orderNo) async {
    if (_pendingActive || _checkoutActive) return;
    final epoch = ref.read(loginEpochProvider);
    _pendingActive = true;
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (_) => PendingMembershipPurchaseSheet(orderNo: orderNo),
      );
      if (mounted && epoch == ref.read(loginEpochProvider)) {
        await _refreshMembership(orderNo: orderNo);
      }
    } finally {
      _pendingActive = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(catalogControllerProvider);
    final purchase = ref.watch(purchaseControllerProvider);
    final wallet = ref.watch(pointsWalletControllerProvider);
    final billing = ref.watch(pointsBillingProvider);
    final controller = ref.read(catalogControllerProvider.notifier);
    return Stack(
      children: [
        MembershipPage(
          key: ValueKey(ref.watch(loginEpochProvider)),
          state: state,
          // Consumable-only storefront; app-scoped automatic recovery stays active.
          showRestore: false,
          modelNames:
              ref.watch(membershipModelNamesProvider).valueOrNull ?? const {},
          availablePoints: wallet.stale
              ? null
              : wallet.account?.availableBalance,
          heldPoints: wallet.stale ? null : wallet.account?.heldBalance,
          pointsPerMinute: billing.isLoading || billing.hasError
              ? null
              : billing.valueOrNull,
          todayDailyGrantReceived:
              !wallet.stale &&
              (wallet.account?.todayDailyGrantReceived ?? false),
          todayDailyGrantPoints: wallet.stale
              ? 0
              : wallet.account?.todayDailyGrantPoints ?? 0,
          onBack: () => Navigator.pop(context),
          onRefresh: () async {
            ref.invalidate(applePurchaseHistoryProvider);
            ref.invalidate(pointsBillingProvider);
            ref.invalidate(membershipModelNamesProvider);
            await _refreshMembership();
          },
          onPoints: () => _push(
            _PointsPurchaseRoute(
              onBuy: (product, owner) => _buy(product, purchaseContext: owner),
              onLegal: _legal,
            ),
          ),
          onOrders: () async {
            final epoch = ref.read(loginEpochProvider);
            await _push(const CommerceOrdersRoute());
            if (mounted && epoch == ref.read(loginEpochProvider)) {
              await _refreshMembership();
            }
          },
          onPending: () {
            final orderNo = state.membership?.pendingOrderNo;
            if (orderNo != null) _pending(orderNo);
          },
          onLedger: _ledger,
          onBuy: () {
            if (!purchase.purchaseBlocked && state.selectedProduct != null) {
              _buy(state.selectedProduct!);
            }
          },
          onReloadProducts: controller.reloadPlatformProducts,
          onAgreement: controller.agreement,
          onLegal: _legal,
          onLevel: controller.selectLevel,
          onMonths: controller.selectMonths,
          onSupport: () =>
              showCommerceSupport(context, state.catalog?.supportEmail),
          onRestore: () async {
            await ref.read(purchaseControllerProvider.notifier).restore();
            if (mounted) await _push(const PurchaseResultRoute());
          },
        ),
        if ((_checkoutActive || purchase.waitingForApple) &&
            purchase.showPaymentOverlay)
          const Positioned.fill(child: PurchaseLoadingOverlay()),
      ],
    );
  }
}

class _PointsPurchaseRoute extends ConsumerWidget {
  const _PointsPurchaseRoute({required this.onBuy, required this.onLegal});
  final void Function(ProductOffer, BuildContext) onBuy;
  final VoidCallback onLegal;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final purchase = ref.watch(purchaseControllerProvider);
    return Stack(
      children: [
        PointsPurchasePage(
          key: ValueKey(ref.watch(loginEpochProvider)),
          state: ref.watch(catalogControllerProvider),
          onBack: () => Navigator.pop(context),
          onBuy: (product) => onBuy(product, context),
          onAgreement: ref.read(catalogControllerProvider.notifier).agreement,
          onLegal: onLegal,
          onRefresh: ref.read(catalogControllerProvider.notifier).load,
          onReloadProducts: ref
              .read(catalogControllerProvider.notifier)
              .reloadPlatformProducts,
          purchaseBlocked: purchase.purchaseBlocked,
        ),
        if (purchase.order?.channel == 'APPLE_IAP' &&
            purchase.showPaymentOverlay)
          const Positioned.fill(child: PurchaseLoadingOverlay()),
      ],
    );
  }
}
