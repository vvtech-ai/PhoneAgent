import '../../../core/network/account_session.dart';
import '../domain/call_session.dart';

/// Keeps the conversation's existing stop feedback/recovery owner in the loop.
class BatchStopCallSessionRepository implements CallSessionRepository {
  BatchStopCallSessionRepository(this.delegate, this.stop);
  final CallSessionRepository delegate;
  final Future<bool> Function() stop;
  @override
  Future<CallSessionSnapshot> status(CallSessionTarget target) =>
      delegate.status(target);
  @override
  Future<CallMonitorTicket> monitorTicket(CallSessionTarget target) =>
      delegate.monitorTicket(target);
  @override
  Future<CallSessionSnapshot> hangUp(CallSessionTarget target) async {
    if (!await stop()) throw ApiFailure.invalidResponse;
    return delegate.status(target);
  }
}
