import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/business_providers.dart';
import '../../../../app/commerce_providers.dart';
import '../../../../core/design/native_confirmation_dialog.dart';
import 'commerce_widgets.dart';
import 'purchase_feedback_sheet.dart';
import 'original_apple_price_dialog.dart';

class PendingMembershipPurchaseSheet extends ConsumerStatefulWidget {
  const PendingMembershipPurchaseSheet({super.key, required this.orderNo});
  final String orderNo;
  @override
  ConsumerState<PendingMembershipPurchaseSheet> createState() =>
      _PendingMembershipPurchaseSheetState();
}

class _PendingMembershipPurchaseSheetState
    extends ConsumerState<PendingMembershipPurchaseSheet>
    with WidgetsBindingObserver {
  Timer? _timer;
  late final int? _epoch;
  bool _foreground = true, _paying = false, _feedback = false;
  bool _confirming = false, _closeRequested = false;
  bool get _current =>
      mounted &&
      _epoch == ref.read(loginEpochProvider) &&
      ModalRoute.of(context)?.isCurrent == true;

  @override
  void initState() {
    super.initState();
    _epoch = ref.read(loginEpochProvider);
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(_query);
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _query());
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) _query();
  }

  Future<void> _query() async {
    if (!_current || !_foreground || _paying || _confirming) return;
    final controller = ref.read(purchaseControllerProvider.notifier);
    if (controller.snapshot.busy) return;
    await controller.query(widget.orderNo);
    if (!mounted || !_current || _feedback) return;
    final order = controller.snapshot.order;
    if (order?.orderNo == widget.orderNo && !order!.unresolved) {
      Navigator.pop(context);
    }
  }

  Future<void> _pay() async {
    final controller = ref.read(purchaseControllerProvider.notifier);
    if (!_current || _paying || controller.snapshot.busy) return;
    setState(() => _paying = true);
    final attempted = await controller.continuePayment(
      isCurrent: () => _current,
      confirmApplePrice: (product) =>
          showOriginalApplePriceDialog(context, product),
    );
    if (!_current) return;
    setState(() {
      _paying = false;
      _feedback = attempted;
    });
  }

  Future<void> _cancel() async {
    final controller = ref.read(purchaseControllerProvider.notifier);
    if (!_current || _confirming || controller.snapshot.busy) return;
    _confirming = true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => const NativeConfirmationDialog(
        title: '取消本次购买？',
        message: '确认取消后将核实支付状态，取消完成后可重新选择套餐。',
        dismissLabel: '暂不取消',
        confirmLabel: '确认取消',
        danger: true,
      ),
    );
    _confirming = false;
    if (confirmed != true || !_current) return;
    setState(() => _closeRequested = true);
    await controller.closeOrder();
    if (!mounted || !_current) return;
    final order = controller.snapshot.order;
    if (order?.orderNo == widget.orderNo && !order!.unresolved) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(purchaseControllerProvider);
    if (_paying) {
      return const SafeArea(
        child: Padding(
          padding: EdgeInsets.all(48),
          child: Center(heightFactor: 1, child: CircularProgressIndicator()),
        ),
      );
    }
    if (_feedback) {
      return PurchaseFeedbackSheet(
        state: state,
        upgrade: false,
        onDone: () => Navigator.pop(context),
      );
    }
    final order = state.order?.orderNo == widget.orderNo ? state.order : null;
    final controller = ref.read(purchaseControllerProvider.notifier);
    final message = order?.paymentState == 'SUCCEEDED'
        ? order!.appState.label
        : order?.cancellationPending == true
        ? '取消处理中，请稍后查看'
        : _closeRequested
        ? '取消结果尚未确认，请稍后刷新状态。'
        : '您有一笔会员购买尚未完成，可继续支付，或取消后重新选择套餐。';
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 28, 22, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '待处理购买',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Color(0xFF777C84)),
            ),
            const SizedBox(height: 16),
            if (state.busy) const LinearProgressIndicator(),
            if (state.error.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                state.error,
                style: const TextStyle(color: Color(0xFFD33A3A)),
              ),
            ],
            if (order?.canRequestPaymentRetry == true &&
                order?.channel == controller.paymentChannel &&
                !controller.appleAttemptPending) ...[
              const SizedBox(height: 12),
              CommerceAction('继续支付', onPressed: state.busy ? null : _pay),
            ],
            if (order?.canRequestClose == true) ...[
              const SizedBox(height: 12),
              CommerceAction(
                '取消本次购买',
                secondary: true,
                onPressed: state.busy ? null : _cancel,
              ),
            ],
            const SizedBox(height: 12),
            CommerceAction(
              '刷新状态',
              secondary: true,
              onPressed: state.busy ? null : _query,
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('稍后再说'),
            ),
          ],
        ),
      ),
    );
  }
}
