import 'dart:async';
import '../../../../core/design/native_page_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/commerce_providers.dart';
import '../../../../app/points_providers.dart';
import '../../../../app/business_providers.dart';
import '../pages/purchase_result_page.dart';
import '../widgets/purchase_feedback_host.dart';
import '../widgets/original_apple_price_dialog.dart';

class PurchaseResultRoute extends ConsumerStatefulWidget {
  const PurchaseResultRoute({super.key, this.orderNo});
  final String? orderNo;
  @override
  ConsumerState<PurchaseResultRoute> createState() =>
      _PurchaseResultRouteState();
}

class _PurchaseResultRouteState extends ConsumerState<PurchaseResultRoute>
    with WidgetsBindingObserver {
  Timer? _timer;
  bool _foreground = true;
  bool _paymentActive = false, _awaitingPayment = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(() {
      if (mounted && widget.orderNo != null) {
        ref.read(purchaseControllerProvider.notifier).query(widget.orderNo!);
      }
    });
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _query());
  }

  void _query() {
    if (!mounted || !_foreground || ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    final state = ref.read(purchaseControllerProvider);
    final orderNo = widget.orderNo ?? state.order?.orderNo;
    if (!state.busy &&
        orderNo != null &&
        (state.order?.orderNo != orderNo ||
            (state.recovery == null && state.order?.unresolved == true))) {
      ref.read(purchaseControllerProvider.notifier).query(orderNo);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) _query();
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _pay() async {
    if (_paymentActive) return;
    final controller = ref.read(purchaseControllerProvider.notifier);
    final order = controller.snapshot.order;
    if (order == null ||
        controller.snapshot.busy ||
        (widget.orderNo != null && order.orderNo != widget.orderNo)) {
      return;
    }
    final epoch = ref.read(loginEpochProvider);
    bool current() =>
        mounted &&
        ModalRoute.of(context)?.isCurrent == true &&
        epoch == ref.read(loginEpochProvider);
    setState(() {
      _paymentActive = true;
      _awaitingPayment = true;
    });
    try {
      final attempted = await controller.continuePayment(
        isCurrent: current,
        confirmApplePrice: (product) =>
            showOriginalApplePriceDialog(context, product),
      );
      if (!attempted || !mounted || !current()) return;
      setState(() => _awaitingPayment = false);
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (_) =>
            PurchaseFeedbackHost(orderNo: order.orderNo, upgrade: false),
      );
    } finally {
      if (mounted) {
        setState(() {
          _paymentActive = false;
          _awaitingPayment = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final shared = ref.watch(purchaseControllerProvider);
    final matches =
        widget.orderNo == null || shared.order?.orderNo == widget.orderNo;
    final state = shared;
    final controller = ref.read(purchaseControllerProvider.notifier);
    ref.listen(purchaseControllerProvider, (before, after) {
      if (before?.order?.fulfillmentState != 'SUCCEEDED' &&
          after.order?.fulfillmentState == 'SUCCEEDED') {
        ref.read(pointsWalletControllerProvider.notifier).refresh();
        ref.read(catalogControllerProvider.notifier).load();
      }
    });
    if (_paymentActive) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: _awaitingPayment
            ? const Center(child: CircularProgressIndicator())
            : const SizedBox.expand(),
      );
    }
    if (!matches) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: const NativePageAppBar(title: '购买结果'),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (shared.busy || shared.error.isEmpty)
                const CircularProgressIndicator(),
              if (shared.error.isNotEmpty) Text(shared.error),
              TextButton(
                onPressed: shared.busy
                    ? null
                    : () => controller.query(widget.orderNo!),
                child: const Text('查询原订单'),
              ),
            ],
          ),
        ),
      );
    }
    return PurchaseResultPage(
      state: state,
      supportEmail: ref.watch(catalogControllerProvider).catalog?.supportEmail,
      paymentAvailable:
          state.order?.channel == controller.paymentChannel &&
          !controller.appleAttemptPending,
      onBack: () => Navigator.pop(context),
      onQuery: () {
        final orderNo = widget.orderNo ?? state.order?.orderNo;
        if (orderNo != null) controller.query(orderNo);
      },
      onPay: _pay,
      onClose: controller.closeOrder,
      onRecovery: controller.previewRecovery,
      onConfirmRecovery: controller.confirmRecovery,
      onDone: () => Navigator.pop(context),
      onSupport: () => showCommerceSupport(
        context,
        ref.read(catalogControllerProvider).catalog?.supportEmail,
      ),
    );
  }
}

Future<void> showCommerceSupport(BuildContext context, String? email) =>
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('联系售后'),
        content: SelectableText(
          email?.isNotEmpty == true ? email! : '售后联系方式暂未配置，请稍后重试',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
