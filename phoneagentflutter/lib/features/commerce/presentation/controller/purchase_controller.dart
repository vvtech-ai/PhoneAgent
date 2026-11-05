import 'ios_payment_runtime.dart';
import 'purchase_launch.dart';
import 'apple_purchase_preflight.dart';
import '../../domain/confirmed_payment_material.dart';
import 'purchase_state.dart';
export 'purchase_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'apple_transaction_verifier.dart';
import '../../domain/apple_cancellation_outbox.dart';
import 'apple_original_price_confirmation.dart';
import 'apple_recovery_subscription.dart';
import '../../data/commerce_diagnostics.dart';
import '../../domain/request_identity.dart';
import '../../domain/commerce_catalog.dart';
import '../../domain/commerce_order.dart';
import '../../domain/commerce_repository.dart';
import '../../domain/payment_launcher.dart';
import '../../domain/apple_recovery_evidence.dart';

class PurchaseController extends StateNotifier<PurchaseState> {
  PurchaseController(
    this.repository,
    this.launcher, {
    this.paymentChannel,
    this.diagnostics,
    this.cancellationOutbox,
    this.onRecoverySucceeded,
  }) : super(const PurchaseState()) {
    _appleVerifier = AppleTransactionVerifier(
      repository,
      launcher,
      () => mounted,
      diagnostics: diagnostics,
      onAccepted: _appleEvidence.accepted,
    );
    _updates = AppleRecoverySubscription(
      launcher,
      enabled: paymentChannel == 'APPLE_IAP',
      diagnostics: diagnostics,
      isCurrent: () => mounted,
      isBusy: () => state.busy,
      recover: () {
        final order = state.order;
        if (order != null) {
          query(order.orderNo);
        } else {
          restore();
        }
      },
    );
  }
  final CommerceDiagnostics? diagnostics;
  final AppleCancellationOutbox? cancellationOutbox;
  final void Function()? onRecoverySucceeded;
  late final AppleTransactionVerifier _appleVerifier;
  late final AppleRecoverySubscription _updates;
  PlatformProduct? _confirmedApple;
  void requestAppleRecovery() => _updates.schedule();

  @override
  void dispose() {
    diagnostics?.event(CommerceStage.dispose, DiagnosticResult.received);
    _updates.dispose();
    super.dispose();
  }

  Future<bool> prepareApplePurchase(
    ProductOffer offer,
    PlatformProduct confirmed,
  ) async {
    if (!mounted || state.busy) return false;
    final revision = _revision;
    var stage = CommerceStage.priceCheck;
    state = PurchaseState(quote: state.quote, order: state.order, busy: true);
    diagnostics?.event(
      CommerceStage.priceCheck,
      DiagnosticResult.started,
      productId: offer.productId,
    );
    try {
      final products = await launcher.products({confirmed.id});
      if (!_current(revision)) return false;
      final fresh = products[confirmed.id];
      if (!confirmsApplePrice(offer, fresh, confirmed)) {
        diagnostics?.product(offer, fresh, false);
        diagnostics?.event(
          CommerceStage.priceCheck,
          DiagnosticResult.failed,
          reason: CommerceReason.priceChanged,
          productId: offer.productId,
        );
        state = PurchaseState(quote: state.quote, error: '商品价格已变化，请刷新后重新确认');
        return false;
      }
      diagnostics?.event(
        CommerceStage.priceCheck,
        DiagnosticResult.succeeded,
        productId: offer.productId,
      );
      stage = CommerceStage.recovery;
      diagnostics?.event(
        stage,
        DiagnosticResult.started,
        productId: offer.productId,
      );
      final recovered = await recoverBeforeApplePurchase(
        launcher,
        _appleVerifier,
        confirmed.id,
        () => _current(revision),
      );
      if (!_current(revision)) return false;
      if (recovered != null) {
        diagnostics?.event(
          stage,
          DiagnosticResult.succeeded,
          orderNo: recovered.orderNo,
        );
        state = PurchaseState(
          order: recovered,
          recoveredPreviousPurchase: true,
        );
        onRecoverySucceeded?.call();
        return false;
      }
      _confirmedApple = fresh;
      diagnostics?.event(
        stage,
        DiagnosticResult.succeeded,
        productId: offer.productId,
      );
      return true;
    } catch (error) {
      if (_current(revision)) {
        diagnostics?.event(
          stage,
          DiagnosticResult.failed,
          productId: offer.productId,
          error: error,
        );
        state = PurchaseState(
          quote: state.quote,
          error: error is CommerceFailure
              ? error.message
              : stage == CommerceStage.priceCheck
              ? 'Apple商品信息加载失败，请重新加载'
              : '上次购买结果暂未确认，请重试后再购买',
        );
      }
      return false;
    } finally {
      if (_current(revision) && state.busy) {
        state = PurchaseState(quote: state.quote, order: state.order);
      }
    }
  }

  bool get applePurchaseActive =>
      launcher is IosPaymentRuntime &&
      (launcher as IosPaymentRuntime).purchaseActive;
  bool _waitingForApple(CommerceOrder? order) =>
      order?.unresolved == true &&
      launcher is IosPaymentRuntime &&
      (launcher as IosPaymentRuntime).waitingFor(order!.orderNo);

  bool get appleAttemptPending =>
      paymentChannel == 'APPLE_IAP' &&
      state.order?.channel == 'APPLE_IAP' &&
      state.order?.unresolved == true &&
      (state.order?.orderNo == _attemptOrderNo
          ? _attemptOutcome != NativePaymentOutcome.canceled
          : state.order?.paymentState != 'PENDING');

  final _appleEvidence = AppleRecoveryEvidence();
  bool get hasOwnedAppleRecovery =>
      paymentChannel == 'APPLE_IAP' && _appleEvidence.visible;

  final CommerceRepository repository;
  final PaymentLauncher launcher;
  final String? paymentChannel;
  PurchaseState get snapshot => state;
  String? _purchaseRequestId, _recoveryRequestId;
  String? _attemptOrderNo, _attemptStatus;
  NativePaymentOutcome? _attemptOutcome;
  String _attemptError = '';
  String? _status(CommerceOrder? order) =>
      order?.orderNo == _attemptOrderNo ? _attemptStatus : null;
  NativePaymentOutcome? _outcome(CommerceOrder? order) =>
      order?.orderNo == _attemptOrderNo ? _attemptOutcome : null;
  int _revision = 0;
  bool _current(int revision) => mounted && revision == _revision;
  String _error(Object error) =>
      error is CommerceFailure ? error.message : '操作结果暂未确认，请查询原订单或重试';

  Future<void> previewUpgrade(String productId, int configVersionId) => preview(
    productId,
    configVersionId,
    agreementAccepted: false,
    upgradeOnly: true,
  );

  Future<void> preview(
    String productId,
    int configVersionId, {
    required bool agreementAccepted,
    bool upgradeOnly = false,
  }) async {
    if (!mounted || state.busy || applePurchaseActive) return;
    if (!agreementAccepted && !upgradeOnly) {
      state = const PurchaseState(error: '请先阅读并同意付费协议');
      return;
    }
    final existing = state.order;
    final revision = ++_revision;
    _confirmedApple = null;
    state = const PurchaseState(busy: true);
    try {
      final quote = await repository.quote(productId, configVersionId);
      if (!_current(revision)) return;
      // Only memberships share an unpaid slot; PACK quotes retain independent transaction identities.
      if (quote.purchaseType != 'PACK' &&
          existing?.productType == 'MEMBERSHIP' &&
          existing?.unresolved == true) {
        state = PurchaseState(order: existing, error: '请先处理原订单');
        return;
      }
      if (upgradeOnly && quote.purchaseType != 'UPGRADE') {
        state = const PurchaseState(error: '会员状态已变化，请刷新后重新选择');
        return;
      }
      _purchaseRequestId = commerceRequestId();
      state = PurchaseState(quote: quote);
    } catch (e) {
      if (_current(revision)) {
        state = PurchaseState(order: existing, error: _error(e));
      }
    }
  }

  Future<void> confirmPurchase(
    String agreementVersion, {
    bool agreementAccepted = true,
    bool Function()? isCurrent,
  }) async {
    final quote = state.quote;
    if (!mounted || state.busy || applePurchaseActive || quote == null) return;
    if (!agreementAccepted) {
      state = PurchaseState(quote: quote, error: '请先阅读并同意付费协议');
      return;
    }
    final revision = ++_revision;
    state = PurchaseState(quote: quote, busy: true);
    try {
      final order = await repository.createOrder(
        quote,
        _purchaseRequestId ??= commerceRequestId(),
        agreementVersion,
      );
      if (!_current(revision)) return;
      state = PurchaseState(order: order, busy: true);
      if (isCurrent?.call() == false) {
        state = PurchaseState(order: order);
        return;
      }
      if (order.canPay &&
          !order.cancellationPending &&
          order.quoteId == quote.quoteId &&
          order.channel == paymentChannel) {
        await _launch(order, revision, isCurrent: isCurrent);
      }
      if (_current(revision) && state.busy) {
        await _query(order.orderNo, revision);
      }
    } catch (e) {
      if (_current(revision)) {
        state = PurchaseState(
          quote: state.order == null ? quote : null,
          order: state.order,
          error: _error(e),
        );
      }
    }
  }

  Future<void> _launch(
    CommerceOrder order,
    int revision, {
    bool Function()? isCurrent,
  }) async {
    _attemptOrderNo = order.orderNo;
    _attemptStatus = null;
    _attemptOutcome = null;
    _attemptError = '';
    await runPurchaseLaunch(
      order: order,
      repository: repository,
      launcher: launcher,
      verifier: _appleVerifier,
      confirmed: _confirmedApple,
      current: () => _current(revision),
      entryCurrent: isCurrent,
      outbox: cancellationOutbox,
      diagnostics: diagnostics,
      onAppleWaiting: () {
        if (_current(revision)) {
          state = PurchaseState(order: order, waitingForApple: true);
        }
      },
      onRecoveredOrder: (original, currentOrder) {
        if (_current(revision)) {
          final separatelyPaid = currentOrder.paymentState == 'SUCCEEDED';
          state = PurchaseState(
            order: currentOrder.unresolved || separatelyPaid
                ? currentOrder
                : original,
            recoveredPreviousPurchase: !separatelyPaid,
            recoveryMessage: currentOrder.unresolved
                ? '上次交易已恢复，本次订单状态仍需查询，请勿重复支付。'
                : '上次交易已恢复，本次购买流程已结束；如 Apple 后续确认付款，将继续处理对应订单。',
          );
          onRecoverySucceeded?.call();
        }
      },
      onVerifiedOrder: (updated) {
        if (_current(revision)) {
          state = PurchaseState(order: updated, busy: updated.unresolved);
          if (!updated.unresolved) onRecoverySucceeded?.call();
        }
      },
      onResult: (material, result) {
        _appleEvidence.launched(material, result);
        _attemptStatus = result.nativeResultStatus;
        _attemptOutcome = result.nativeOutcome;
        if (launcher is IosPaymentRuntime && _current(revision)) {
          state = PurchaseState(order: order, busy: true);
        }
      },
      onError: (error) {
        if (!_current(revision)) return;
        if (error is CommerceFailure) _attemptError = error.message;
        if (launcher is! IosPaymentRuntime) return;
        state = PurchaseState(
          order: state.order ?? order,
          nativeOutcome: _attemptOutcome,
          error: _attemptError.isEmpty ? _error(error) : _attemptError,
        );
      },
    );
  }

  Future<bool> continuePayment({
    bool Function()? isCurrent,
    Future<bool> Function(PlatformProduct)? confirmApplePrice,
  }) async {
    final order = state.order;
    if (!mounted ||
        state.busy ||
        order == null ||
        !order.canRequestPaymentRetry ||
        appleAttemptPending ||
        isCurrent?.call() == false ||
        (paymentChannel != null && order.channel != paymentChannel)) {
      return false;
    }
    final revision = ++_revision;
    state = PurchaseState(order: order, busy: true);
    try {
      if (order.channel == 'APPLE_IAP') {
        _confirmedApple = await confirmOriginalApplePrice(
          order: order,
          repository: repository,
          launcher: launcher,
          isCurrent: () => _current(revision) && isCurrent?.call() != false,
          confirm: confirmApplePrice,
        );
        if (!_current(revision)) return false;
        if (_confirmedApple == null) {
          state = PurchaseState(order: order);
          return false;
        }
      }
      await _launch(order, revision, isCurrent: isCurrent);
      if (_current(revision) && state.busy) {
        await _query(order.orderNo, revision);
      }
      return true;
    } catch (e) {
      if (_current(revision)) {
        state = PurchaseState(order: order, error: _error(e));
      }
      return true;
    }
  }

  Future<void> query(String orderNo) async {
    if (!mounted || state.busy) return;
    final revision = ++_revision;
    state = PurchaseState(
      order: state.order?.orderNo == orderNo ? state.order : null,
      nativeResultStatus: _status(
        state.order?.orderNo == orderNo ? state.order : null,
      ),
      nativeOutcome: _outcome(
        state.order?.orderNo == orderNo ? state.order : null,
      ),
      busy: true,
    );
    await _query(orderNo, revision);
  }

  Future<void> _query(String orderNo, int revision) =>
      _boundedRecovery(_readOrder(orderNo, revision), revision);

  Future<void> _boundedRecovery(Future<void> work, int revision) async {
    if (launcher is! IosPaymentRuntime) return work;
    final completed = await (launcher as IosPaymentRuntime).boundRecovery(work);
    if (completed || !_current(revision)) return;
    ++_revision;
    state = PurchaseState(
      order: state.order,
      waitingForApple: _waitingForApple(state.order),
      error: const CommerceFailure('APPLE_RECOVERY_TIMEOUT').message,
    );
  }

  Future<void> _readOrder(String orderNo, int revision) async {
    try {
      if (paymentChannel == 'APPLE_IAP' ||
          state.order?.channel == 'APPLE_IAP') {
        await _appleVerifier.recover(() => _current(revision));
        if (!_current(revision)) return;
      }
      final order = await repository.order(orderNo);
      if (order.orderNo != orderNo) {
        throw const FormatException('Order mismatch');
      }
      if (_current(revision)) {
        state = PurchaseState(
          order: order,
          waitingForApple: _waitingForApple(order),
          nativeResultStatus: _status(order),
          nativeOutcome: _outcome(order),
          error:
              order.paymentState != 'SUCCEEDED' &&
                  (launcher is! IosPaymentRuntime || order.unresolved) &&
                  order.orderNo == _attemptOrderNo
              ? _attemptError
              : '',
        );
        onRecoverySucceeded?.call();
      }
    } catch (e) {
      if (_current(revision)) {
        state = PurchaseState(
          order: state.order,
          waitingForApple: _waitingForApple(state.order),
          nativeResultStatus: _status(state.order),
          nativeOutcome: _outcome(state.order),
          error: _error(e),
        );
      }
    }
  }

  Future<void> closeOrder() async {
    final order = state.order;
    if (!mounted || state.busy || order == null || !order.canRequestClose) {
      return;
    }
    final revision = ++_revision;
    state = PurchaseState(order: order, busy: true);
    try {
      final result = await repository.closeOrder(
        order.orderNo,
        commerceRequestId(),
      );
      if (_current(revision)) state = PurchaseState(order: result);
    } catch (e) {
      if (_current(revision)) {
        state = PurchaseState(order: order, error: _error(e));
      }
    }
  }

  Future<void> previewRecovery() async {
    final order = state.order;
    if (!mounted || state.busy || order == null || !order.recoveryRequired) {
      return;
    }
    final revision = ++_revision;
    state = PurchaseState(order: order, busy: true);
    try {
      final preview = await repository.recoveryPreview(order.orderNo);
      if (preview.orderNo != order.orderNo) {
        throw const FormatException('Recovery mismatch');
      }
      if (!_current(revision)) return;
      _recoveryRequestId = commerceRequestId();
      state = PurchaseState(order: order, recovery: preview);
    } catch (e) {
      if (_current(revision)) {
        state = PurchaseState(order: order, error: _error(e));
      }
    }
  }

  Future<void> confirmRecovery() async {
    final preview = state.recovery;
    if (!mounted || state.busy || preview == null) return;
    final revision = ++_revision;
    state = PurchaseState(order: state.order, recovery: preview, busy: true);
    try {
      final order = await repository.recoveryConfirm(
        preview,
        _recoveryRequestId ??= commerceRequestId(),
      );
      if (_current(revision)) state = PurchaseState(order: order);
    } catch (e) {
      if (!_current(revision)) return;
      final expired =
          e is CommerceFailure && e.code == 'RECOVERY_PREVIEW_EXPIRED';
      state = PurchaseState(
        order: state.order,
        recovery: expired ? null : preview,
        error: _error(e),
      );
    }
  }

  Future<void> restore() async {
    if (!mounted || state.busy) return;
    final clock = Stopwatch()..start();
    diagnostics?.event(CommerceStage.recovery, DiagnosticResult.started);
    await _boundedRecovery(_restore(), _revision);
    if (mounted) {
      diagnostics?.event(
        CommerceStage.recovery,
        state.error.isEmpty
            ? DiagnosticResult.succeeded
            : DiagnosticResult.failed,
        orderNo: state.order?.orderNo ?? '',
        elapsedMs: clock.elapsedMilliseconds,
        reason: state.error.isEmpty ? null : CommerceReason.rejected,
      );
    }
  }

  Future<void> _restore() async {
    if (!mounted || state.busy) return;
    final revision = ++_revision;
    state = PurchaseState(order: state.order, busy: true);
    try {
      await _appleVerifier.recover(() => _current(revision));
      if (!_current(revision)) return;
      final membership = await repository.membership();
      if (!_current(revision)) return;
      final pending =
          membership.pendingOrderNo ??
          (launcher is IosPaymentRuntime
              ? (launcher as IosPaymentRuntime).pendingOrderNo
              : null);
      if (pending != null) {
        await _query(pending, revision);
        return;
      }
      final page = await repository.orders(0);
      if (!_current(revision)) return;
      final unresolved = page.items.where((o) => o.unresolved);
      state = PurchaseState(
        order: unresolved.isEmpty ? null : unresolved.first,
      );
      onRecoverySucceeded?.call();
    } catch (e) {
      if (_current(revision)) {
        state = PurchaseState(order: state.order, error: _error(e));
      }
    }
  }
}
