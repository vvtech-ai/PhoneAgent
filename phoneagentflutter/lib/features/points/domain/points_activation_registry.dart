import 'points_activation.dart';

/// One configured app process, not persistent daily reward eligibility.
class PointsActivationRegistry {
  final Set<String> _activated = {};
  final Map<String, Future<PointsActivation>> _pending = {};

  void markActivated(String account) => _activated.add(account);

  Future<PointsActivation?> activateIfNeeded(
    String account,
    Future<PointsActivation> Function() activate,
  ) async {
    if (account.trim().isEmpty || _activated.contains(account)) return null;
    final existing = _pending[account];
    if (existing != null) {
      await existing;
      return null;
    }
    final work = Future<PointsActivation>.sync(activate);
    _pending[account] = work;
    try {
      final result = await work;
      _activated.add(account);
      return result;
    } finally {
      if (identical(_pending[account], work)) _pending.remove(account);
    }
  }
}
