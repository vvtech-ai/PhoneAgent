import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/account_cancellation.dart';

class CancellationState {
  const CancellationState({
    this.busy = false,
    this.delivery,
    this.cooldown = 0,
    this.notice = '',
    this.unknown = false,
    this.result,
    this.verification,
  });
  final bool busy, unknown;
  final CancellationDelivery? delivery;
  final int cooldown;
  final String notice;
  final CancellationResult? result;
  final CancellationVerification? verification;
}

class CancellationController extends StateNotifier<CancellationState> {
  CancellationController(
    this.gateway,
    this.confirmation, {
    required this.isCurrent,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now,
       super(const CancellationState());
  CancellationState get snapshot => state;
  final CancellationGateway gateway;
  final CancellationConfirmation confirmation;
  final bool Function() isCurrent;
  final DateTime Function() _now;
  final operationId = cancellationOperationId();
  Timer? _ticker;
  DateTime? _resendAt;
  bool get _current => mounted && isCurrent();
  Future<void> send() async {
    if (!_current ||
        state.busy ||
        state.unknown ||
        state.result != null ||
        state.cooldown > 0) {
      return;
    }
    state = CancellationState(busy: true, delivery: state.delivery);
    try {
      final delivery = await gateway.send(confirmation, operationId);
      if (!_current) return;
      _resendAt = _now().add(Duration(seconds: delivery.cooldownSeconds));
      state = CancellationState(
        delivery: delivery,
        cooldown: delivery.cooldownSeconds,
        notice: '验证码已发送',
      );
      _ticker?.cancel();
      _ticker = Timer.periodic(
        const Duration(seconds: 1),
        (_) => refreshCooldown(),
      );
    } catch (error) {
      if (_current) {
        state = CancellationState(
          delivery: state.delivery,
          notice: cancellationNotice(error, '获取验证码失败，请稍后重试'),
        );
      }
    }
  }

  void refreshCooldown() {
    if (!_current || _resendAt == null) return;
    final left = (_resendAt!.difference(_now()).inMilliseconds / 1000).ceil();
    state = CancellationState(
      busy: state.busy,
      delivery: state.delivery,
      cooldown: left > 0 ? left : 0,
      notice: state.notice,
      unknown: state.unknown,
      result: state.result,
      verification: state.verification,
    );
    if (left <= 0) _ticker?.cancel();
  }

  Future<void> verify(String code) async {
    if (!_current ||
        state.busy ||
        state.unknown ||
        state.result != null ||
        state.delivery == null) {
      return;
    }
    if (!RegExp(r'^\d{6}$').hasMatch(code)) return;
    final delivery = state.delivery!;
    state = CancellationState(
      busy: true,
      delivery: delivery,
      cooldown: state.cooldown,
    );
    try {
      final verification = await gateway.verify(delivery, operationId, code);
      if (_current) {
        state = CancellationState(
          delivery: delivery,
          cooldown: state.cooldown,
          verification: verification,
        );
      }
    } catch (error) {
      if (_current) {
        state = CancellationState(
          delivery: delivery,
          cooldown: state.cooldown,
          notice: cancellationNotice(error, '验证失败，请检查验证码或重新获取后重试'),
        );
      }
    }
  }

  /// Only abandons a local, unsubmitted proof; unknown applications must recover.
  void discardVerification() {
    if (!_current ||
        state.busy ||
        state.unknown ||
        state.result != null ||
        state.verification == null) {
      return;
    }
    state = CancellationState(
      delivery: state.delivery,
      cooldown: state.cooldown,
      notice: state.notice,
    );
  }

  Future<void> submit() async {
    if (!_current ||
        state.busy ||
        state.result != null ||
        state.delivery == null) {
      return;
    }
    if (state.unknown) {
      await recover();
      return;
    }
    final verification = state.verification;
    if (verification == null) return;
    final delivery = state.delivery!;
    state = CancellationState(
      busy: true,
      delivery: delivery,
      cooldown: state.cooldown,
      verification: verification,
    );
    try {
      final result = await gateway.submit(
        delivery,
        operationId,
        verification.token,
      );
      if (_current) _apply(result);
    } catch (error) {
      // Known business refusal may explain NOT_SUBMITTED; it never replaces lookup.
      if (_current) await recover(rejection: error);
    }
  }

  Future<void> recover({Object? rejection}) async {
    if (!_current || state.delivery == null) return;
    final delivery = state.delivery!;
    state = CancellationState(
      busy: true,
      delivery: delivery,
      cooldown: state.cooldown,
      unknown: true,
      verification: state.verification,
    );
    try {
      final result = await gateway.lookup(delivery, operationId);
      if (_current) _apply(result, rejection: rejection);
    } catch (_) {
      if (_current) {
        state = CancellationState(
          delivery: delivery,
          cooldown: state.cooldown,
          unknown: true,
          notice: '申请结果暂未确认，请点击查询结果',
          verification: state.verification,
        );
      }
    }
  }

  void _apply(CancellationResult result, {Object? rejection}) {
    state = CancellationState(
      delivery: state.delivery,
      cooldown: state.cooldown,
      result: result.accepted ? result : null,
      notice: result.accepted
          ? ''
          : result.status == 'NOT_SUBMITTED'
          ? cancellationNotice(rejection ?? Object(), '申请未受理，请重新验证后重试')
          : '申请状态已变化，请重新进入',
    );
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
