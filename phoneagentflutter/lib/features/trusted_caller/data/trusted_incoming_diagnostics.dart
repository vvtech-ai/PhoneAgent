import '../../../core/diagnostics/diagnostic_event.dart';

/// Only fixed metadata is accepted; native identity/error bodies never enter logs.
class TrustedIncomingDiagnostics {
  const TrustedIncomingDiagnostics(this.sink, this.environment);
  final DiagnosticSink? sink;
  final String environment;

  void record(
    DiagnosticTrustedCallerStage stage,
    String code,
    DiagnosticResult result, {
    DateTime? time,
    String? errorDomain,
    int? errorCode,
  }) {
    if (!DiagnosticTrustedCallerDetails.codes.contains(code)) return;
    emitDiagnostic(
      sink,
      DiagnosticEvent(
        operation: DiagnosticOperation.trustedCaller,
        result: result,
        time: time,
        trustedCaller: DiagnosticTrustedCallerDetails(
          stage,
          DiagnosticTrustedCallerPlatform.ios,
          environment == 'pro'
              ? DiagnosticTrustedCallerEnvironment.pro
              : DiagnosticTrustedCallerEnvironment.test,
          code: code,
          errorDomain: result == DiagnosticResult.failed ? errorDomain : null,
          errorCode: result == DiagnosticResult.failed ? errorCode : null,
        ),
      ),
    );
  }

  bool consume(Object? event) {
    if (event is! Map || !event.containsKey('diagnostic')) return false;
    final raw = event['diagnostic'];
    if (raw is! Map) return true;
    final stage = DiagnosticTrustedCallerStage.values
        .where((item) => item.name == raw['stage'])
        .firstOrNull;
    final result = DiagnosticResult.values
        .where((item) => item.name == raw['result'])
        .firstOrNull;
    final code = raw['code'];
    final milliseconds = raw['timeMs'];
    if (stage == null ||
        !{
          DiagnosticTrustedCallerStage.incomingReceive,
          DiagnosticTrustedCallerStage.incomingPayload,
          DiagnosticTrustedCallerStage.incomingCache,
          DiagnosticTrustedCallerStage.incomingVerify,
          DiagnosticTrustedCallerStage.incomingDelivery,
          DiagnosticTrustedCallerStage.incomingActivity,
          DiagnosticTrustedCallerStage.incomingAvatar,
          DiagnosticTrustedCallerStage.pushRegistration,
          DiagnosticTrustedCallerStage.pushBinding,
        }.contains(stage) ||
        result == null ||
        code is! String ||
        !code.startsWith('IOS_') ||
        milliseconds is! int ||
        milliseconds < 0 ||
        milliseconds > DateTime.now().millisecondsSinceEpoch + 60000) {
      return true;
    }
    record(
      stage,
      code,
      result,
      time: DateTime.fromMillisecondsSinceEpoch(milliseconds, isUtc: true),
      errorDomain: raw['errorDomain'] is String
          ? raw['errorDomain'] as String
          : null,
      errorCode: DiagnosticTrustedCallerDetails.boundedErrorCode(
        raw['errorCode'],
      ),
    );
    return true;
  }
}
