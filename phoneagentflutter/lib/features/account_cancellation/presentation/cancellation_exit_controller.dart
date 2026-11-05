import 'package:flutter/foundation.dart';
import '../../../core/network/account_session.dart';
import 'cancellation_controller.dart';

/// Inert presentation data only: no code, verification/query token or live page.
class CancellationExitFrame {
  const CancellationExitFrame({
    required this.token,
    required this.accountId,
    required this.epoch,
    required this.maskedPhone,
    required this.cooldown,
    this.accepted = false,
    this.busy = true,
  });
  final Object token;
  final String accountId;
  final int epoch, cooldown;
  final String? maskedPhone;
  final bool accepted, busy;

  CancellationExitFrame withStatus({
    Object? token,
    bool? accepted,
    bool? busy,
  }) => CancellationExitFrame(
    token: token ?? this.token,
    accountId: accountId,
    epoch: epoch,
    maskedPhone: maskedPhone,
    cooldown: cooldown,
    accepted: accepted ?? this.accepted,
    busy: busy ?? this.busy,
  );
}

/// Owns a single transient visual across account-page disposal/router replacement.
/// SessionController alone owns permissions, storage and release ordering.
class CancellationExitController extends ChangeNotifier {
  CancellationExitFrame? _frame;
  bool _disposed = false;
  CancellationExitFrame? get frame => _frame;
  bool get visible => _frame?.busy == true;

  Object begin(AccountCredentials owner, CancellationState display) {
    final token = Object();
    if (_disposed) return token;
    _frame = CancellationExitFrame(
      token: token,
      accountId: owner.accountId,
      epoch: owner.epoch,
      maskedPhone: display.delivery?.maskedPhone,
      cooldown: display.cooldown,
    );
    notifyListeners();
    return token;
  }

  bool _owns(Object? token) =>
      !_disposed && token != null && identical(token, _frame?.token);
  void accepted(Object token) {
    if (!_owns(token)) return;
    _frame = _frame!.withStatus(accepted: true);
    notifyListeners();
  }

  void fail(Object token) {
    if (!_owns(token)) return;
    _frame = _frame!.accepted ? _frame!.withStatus(busy: false) : null;
    notifyListeners();
  }

  Object? retryCleanup() {
    if (_disposed || _frame?.accepted != true || visible) return null;
    final token = Object();
    _frame = _frame!.withStatus(token: token, busy: true);
    notifyListeners();
    return token;
  }

  void revealLogin(Object token) {
    if (!_owns(token) || !_frame!.accepted) return;
    _frame = null;
    notifyListeners();
  }

  void identityChanged({
    required String? accountId,
    required int? epoch,
    required bool signedOut,
  }) {
    if (_disposed || _frame == null) return;
    if (signedOut && _frame!.accepted) {
      return; // Root waits for the login frame.
    }
    if (accountId == _frame!.accountId && epoch == _frame!.epoch) return;
    _frame = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _frame = null;
    super.dispose();
  }
}
