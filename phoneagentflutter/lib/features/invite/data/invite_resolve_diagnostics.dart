import '../../../../core/diagnostics/diagnostic_event.dart';

/// Captures the request's owner once. Logging failures cannot affect the query.
class InviteResolveDiagnostics {
  InviteResolveDiagnostics._(this._sink) {
    _emit(
      DiagnosticResult.started,
      DiagnosticInviteResolveOutcome.started,
      0,
      null,
    );
  }
  factory InviteResolveDiagnostics(DiagnosticSink? Function()? lookup) {
    DiagnosticSink? sink;
    try {
      sink = lookup?.call();
    } catch (_) {}
    return InviteResolveDiagnostics._(sink);
  }
  final DiagnosticSink? _sink;
  final Stopwatch _watch = Stopwatch()..start();
  void finish(String? error, {required int status, Object? apiCode}) => _emit(
    error == null ? DiagnosticResult.succeeded : DiagnosticResult.failed,
    switch (error) {
      null => DiagnosticInviteResolveOutcome.active,
      'ACTIVITY_RETIRED' || 'INVITE_ACTIVITY_RETIRED' =>
        DiagnosticInviteResolveOutcome.activityRetired,
      'EXPIRED' || 'INVITE_EXPIRED' => DiagnosticInviteResolveOutcome.expired,
      'EXHAUSTED' ||
      'QUOTA_EXHAUSTED' ||
      'INVITE_EXHAUSTED' => DiagnosticInviteResolveOutcome.exhausted,
      'REPLACED' ||
      'INVITE_REPLACED' => DiagnosticInviteResolveOutcome.replaced,
      'INVALID_CODE' ||
      'INVITE_INVALID' ||
      'INVITE_CODE_FORMAT_INVALID' ||
      'INVITE_NOT_FOUND' => DiagnosticInviteResolveOutcome.invalidCode,
      'INVITE_ACTIVITY_CHANGED' =>
        DiagnosticInviteResolveOutcome.activityChanged,
      'CONFIG_NOT_PUBLISHED' =>
        DiagnosticInviteResolveOutcome.configNotPublished,
      'CONFIG_SYNCING' ||
      'CONFIG_SYNC_PENDING' => DiagnosticInviteResolveOutcome.configSyncPending,
      'EXTERNAL_INVITE_UNAVAILABLE' ||
      'UNAVAILABLE' => DiagnosticInviteResolveOutcome.serviceUnavailable,
      'NETWORK' => DiagnosticInviteResolveOutcome.network,
      'INVALID_RESPONSE' => DiagnosticInviteResolveOutcome.invalidResponse,
      'CONFIG_UNAVAILABLE' => DiagnosticInviteResolveOutcome.configUnavailable,
      _ => DiagnosticInviteResolveOutcome.unknown,
    },
    status,
    apiCode,
  );
  void _emit(
    DiagnosticResult result,
    DiagnosticInviteResolveOutcome outcome,
    int status,
    Object? code,
  ) {
    try {
      _sink?.call(
        DiagnosticEvent(
          operation: DiagnosticOperation.inviteResolve,
          result: result,
          statusCode: status,
          elapsedMs: _watch.elapsedMilliseconds,
          inviteResolve: DiagnosticInviteResolveDetails(
            outcome,
            code == 0
                ? DiagnosticInviteApiCode.numericSuccess
                : code == '000000'
                ? DiagnosticInviteApiCode.stringSuccess
                : code == null
                ? DiagnosticInviteApiCode.unknown
                : DiagnosticInviteApiCode.rejected,
          ),
        ),
      );
    } catch (_) {}
  }
}
