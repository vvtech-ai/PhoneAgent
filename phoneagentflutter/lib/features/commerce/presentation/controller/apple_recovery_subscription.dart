import 'dart:async';
import '../../data/commerce_diagnostics.dart';
import '../../domain/payment_launcher.dart';

/// Account-scoped notification lifetime, separate from checkout state.
class AppleRecoverySubscription {
  AppleRecoverySubscription(
    PaymentLauncher launcher, {
    required bool enabled,
    required this.isCurrent,
    required this.isBusy,
    required this.recover,
    this.diagnostics,
  }) {
    if (enabled && launcher is AppleTransactionUpdates) {
      _subscription = (launcher as AppleTransactionUpdates).transactionUpdates
          .listen(
            (_) {
              diagnostics?.event(
                CommerceStage.transactionUpdate,
                DiagnosticResult.received,
              );
              schedule();
            },
            onError: (Object error) {
              diagnostics?.event(
                CommerceStage.transactionUpdate,
                DiagnosticResult.failed,
                error: error,
              );
            },
          );
    }
  }
  final bool Function() isCurrent, isBusy;
  final void Function() recover;
  final CommerceDiagnostics? diagnostics;
  StreamSubscription<void>? _subscription;
  Timer? _timer;
  void schedule() {
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 250), () {
      if (!isCurrent()) return;
      if (isBusy()) {
        schedule();
        return;
      }
      recover();
    });
  }

  void dispose() {
    _subscription?.cancel();
    _timer?.cancel();
  }
}
