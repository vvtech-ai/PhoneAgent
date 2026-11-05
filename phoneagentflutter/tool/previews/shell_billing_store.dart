import 'package:phone_agent/features/calls/domain/confirmation_billing.dart';

/// Isolated workbench storage; never uses device storage or legacy channels.
class ShellBillingStore implements ConfirmationBillingStore {
  final _values = <String, ConfirmationBillingSnapshot>{};
  @override
  Future<ConfirmationBillingSnapshot> resolve(
    ConfirmationBillingRequest request,
    ConfirmationBillingSnapshot current,
  ) async {
    final keys = [
      for (final alias in request.aliases) '${request.sessionId}\u0000$alias',
    ];
    final prior = keys
        .map((key) => _values[key])
        .whereType<ConfirmationBillingSnapshot>()
        .firstOrNull;
    if (prior == null && !request.captureCurrent) {
      return const ConfirmationBillingSnapshot();
    }
    final snapshot = prior ?? current;
    for (final key in keys) {
      _values[key] = snapshot;
    }
    return snapshot;
  }
}
