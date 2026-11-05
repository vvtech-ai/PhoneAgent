import 'call_admission.dart';
import 'call_launch_request.dart';

/// Per conversation. A missing balance delegates to the backend atomic check;
/// failed notice persistence never turns a known-insufficient balance into allow.
class CallAdmissionService {
  CallAdmissionService({
    required this.store,
    required this.notices,
    required this.readBalance,
    required this.refreshBalance,
    required this.readModel,
    this.modelAvailable,
    this.wait = Future<void>.delayed,
  });
  final CallAdmissionNoticeStore store;
  final CallAdmissionNoticeRepository notices;
  final int? Function() readBalance;
  final String? Function() readModel;
  final bool Function()? modelAvailable;
  bool get modelReady => modelAvailable?.call() ?? true;
  void ensureModelAvailable() {
    if (!modelReady) throw StateError('Call model is not currently available');
  }

  final Future<int?> Function() refreshBalance;
  final Future<void> Function(Duration) wait;
  final Map<String, Set<String>> _remembered = {};

  Future<CallAdmissionDecision?> evaluate(
    CallLaunchRequest request, {
    required Iterable<CallLaunchRequest> priorRequests,
    required bool Function() isCurrent,
    bool onlyRepeated = false,
  }) async {
    if (!request.isValid) throw const FormatException('Invalid call request');
    if (!isCurrent()) return null;
    ensureModelAvailable();
    final aliases = <String>{
      ...request.aliases,
      for (final prior in priorRequests)
        if (request.sameTask(prior)) ...prior.aliases,
    };
    var notified = aliases.any((_remembered[request.sessionId] ?? {}).contains);
    var persistenceFailed = false;
    try {
      notified =
          await store.wasNotified(request.sessionId, aliases) || notified;
    } catch (_) {
      persistenceFailed = true;
    }
    if (!isCurrent()) return null;
    ensureModelAvailable();
    CallAdmissionDecision decide(int? balance) => CallAdmissionPolicy.evaluate(
      balance: balance,
      model: readModel(),
      recipients: request.confirmation.recipientCount,
      notified: notified,
      persistenceFailed: persistenceFailed,
    );
    var decision = decide(readBalance());
    // A visible confirmation may outlive the wallet snapshot. Recheck before
    // execution; restored text input still gates only an already-known notice.
    if (!onlyRepeated ||
        decision.kind == CallAdmissionKind.repeatedInsufficient) {
      final balance = await refreshBalance();
      if (!isCurrent()) return null;
      ensureModelAvailable();
      decision = decide(balance);
    }
    // Restored confirmation gates only a repeated insufficiency. The user's
    // next turn is not a request to execute the historical call automatically.
    if (onlyRepeated && decision.kind == CallAdmissionKind.firstInsufficient) {
      return const CallAdmissionDecision(CallAdmissionKind.allow);
    }
    if (decision.kind != CallAdmissionKind.allow) {
      (_remembered[request.sessionId] ??= {}).addAll(request.aliases);
    }
    return decision;
  }

  /// Notify UI before awaiting this best-effort persistence operation.
  Future<bool> record(
    CallLaunchRequest request, {
    required bool Function() isCurrent,
    bool commitNotice = true,
  }) async {
    var saved = true;
    if (!isCurrent()) return false;
    try {
      await store.markNotified(request.sessionId, request.aliases);
    } catch (_) {
      saved = false;
    }
    if (!isCurrent()) return false;
    if (!commitNotice) return saved;
    for (var attempt = 0; attempt < 3; attempt++) {
      if (!isCurrent()) return false;
      try {
        await notices.commit(request);
        return saved && isCurrent();
      } on CallAdmissionNoticeFailure catch (error) {
        if (error != CallAdmissionNoticeFailure.retryable || attempt == 2) {
          return false;
        }
        if (!isCurrent()) return false;
        await wait(const Duration(milliseconds: 300));
      } catch (_) {
        return false;
      }
    }
    return false;
  }
}
