import '../../../core/diagnostics/diagnostic_auth_details.dart';
import '../../../core/diagnostics/diagnostic_event.dart';
import '../domain/auth_gateway.dart';

/// One per request: concurrent responses cannot overwrite status or ownership.
class AuthRequestDiagnostics {
  AuthRequestDiagnostics(
    this.operation,
    DiagnosticSink? Function()? selectSink,
  ) {
    try {
      _sink = selectSink?.call();
    } catch (_) {
      // Selecting diagnostics must not prevent a real authentication request.
    }
  }

  final DiagnosticOperation operation;
  final Stopwatch _clock = Stopwatch()..start();
  DiagnosticSink? _sink;
  int statusCode = 0;

  Future<T> run<T>(
    Future<T> Function() action,
    DiagnosticAuthOutcome Function(T) outcome,
  ) async {
    try {
      final value = await action();
      _record(DiagnosticResult.succeeded, outcome(value));
      return value;
    } on AuthFailure catch (failure) {
      _record(DiagnosticResult.failed, _failure(failure));
      rethrow;
    } catch (_) {
      _record(DiagnosticResult.failed, DiagnosticAuthOutcome.unknown);
      rethrow;
    }
  }

  void _record(DiagnosticResult result, DiagnosticAuthOutcome outcome) {
    _clock.stop();
    emitDiagnostic(
      _sink,
      DiagnosticEvent(
        operation: operation,
        result: result,
        statusCode: statusCode,
        elapsedMs: _clock.elapsedMilliseconds,
        auth: DiagnosticAuthDetails(outcome),
      ),
    );
  }

  static DiagnosticAuthOutcome _failure(AuthFailure failure) =>
      switch (failure) {
        AuthFailure.unavailable => DiagnosticAuthOutcome.unavailable,
        AuthFailure.rejected ||
        AuthFailure.accountCancelled => DiagnosticAuthOutcome.rejected,
        AuthFailure.network ||
        AuthFailure.timeout ||
        AuthFailure.offline => DiagnosticAuthOutcome.network,
        AuthFailure.invalidResponse => DiagnosticAuthOutcome.invalidResponse,
        AuthFailure.storage => DiagnosticAuthOutcome.storage,
        AuthFailure.codeExpired => DiagnosticAuthOutcome.codeExpired,
        AuthFailure.incorrectCode => DiagnosticAuthOutcome.incorrectCode,
        AuthFailure.challengeExpired => DiagnosticAuthOutcome.challengeExpired,
        AuthFailure.invalidInvite => DiagnosticAuthOutcome.invalidInvite,
        AuthFailure.rateLimited => DiagnosticAuthOutcome.rateLimited,
      };
}
