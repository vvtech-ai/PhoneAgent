import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/commerce_providers.dart';
import '../../../../app/membership_purchase_snapshot_provider.dart';
import '../payment_attempt_feedback.dart';
import 'purchase_feedback_sheet.dart';
import 'membership_payment_feedback.dart';

class PurchaseFeedbackHost extends ConsumerStatefulWidget {
  const PurchaseFeedbackHost({
    super.key,
    required this.orderNo,
    required this.upgrade,
    this.membership = false,
  });
  final String orderNo;
  final bool upgrade;
  final bool membership;
  @override
  ConsumerState<PurchaseFeedbackHost> createState() =>
      _PurchaseFeedbackHostState();
}

class _PurchaseFeedbackHostState extends ConsumerState<PurchaseFeedbackHost>
    with WidgetsBindingObserver {
  Timer? _timer;
  bool _foreground = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _query());
  }

  void _query({bool explicit = false}) {
    if (!mounted || !_foreground || ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    final state = ref.read(purchaseControllerProvider);
    if (!state.busy &&
        state.order?.orderNo == widget.orderNo &&
        (state.order?.unresolved == true ||
            (explicit && state.order?.canQueryPayment == true))) {
      ref.read(purchaseControllerProvider.notifier).query(widget.orderNo);
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

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(purchaseControllerProvider);
    if (widget.membership) {
      final completed =
          state.order?.orderNo == widget.orderNo &&
          paymentAttemptFeedback(state).completed;
      final snapshot = completed
          ? ref.watch(membershipPurchaseSnapshotProvider(widget.orderNo))
          : null;
      final fresh = snapshot?.isLoading == false && snapshot?.hasError == false
          ? snapshot?.valueOrNull
          : null;
      return MembershipPaymentFeedback(
        state: state,
        upgrade: widget.upgrade,
        onDone: () => Navigator.pop(context),
        currentMembership: fresh?.membership,
        availablePoints: fresh?.wallet.availableBalance,
        snapshotFailed: snapshot?.hasError == true,
        onQuery: completed
            ? () => ref.invalidate(
                membershipPurchaseSnapshotProvider(widget.orderNo),
              )
            : () => _query(explicit: true),
      );
    }
    return PurchaseFeedbackSheet(
      state: state,
      upgrade: widget.upgrade,
      onDone: () => Navigator.pop(context),
    );
  }
}
