import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../core/diagnostics/diagnostic_event.dart';
import '../domain/trusted_caller.dart';

Future<T> traceTrustedCaller<T>({
  required DiagnosticTrustedCallerStage stage,
  required String environment,
  required Future<T> Function() action,
  TargetPlatform? platform,
  DiagnosticSink? sink,
}) async {
  final clock = Stopwatch()..start();
  final device = platform ?? defaultTargetPlatform;
  DiagnosticEvent event(DiagnosticResult result, [String code = '']) =>
      DiagnosticEvent(
        operation: DiagnosticOperation.trustedCaller,
        result: result,
        elapsedMs: clock.elapsedMilliseconds,
        trustedCaller: DiagnosticTrustedCallerDetails(
          stage,
          device == TargetPlatform.android
              ? DiagnosticTrustedCallerPlatform.android
              : device == TargetPlatform.iOS
              ? DiagnosticTrustedCallerPlatform.ios
              : DiagnosticTrustedCallerPlatform.other,
          environment == 'test'
              ? DiagnosticTrustedCallerEnvironment.test
              : environment == 'pro'
              ? DiagnosticTrustedCallerEnvironment.pro
              : DiagnosticTrustedCallerEnvironment.other,
          code: code,
        ),
      );
  emitDiagnostic(sink, event(DiagnosticResult.started));
  try {
    final value = await action();
    emitDiagnostic(
      sink,
      event(
        value == false ? DiagnosticResult.failed : DiagnosticResult.succeeded,
        value == false ? 'SDK_UNAVAILABLE' : '',
      ),
    );
    return value;
  } catch (error) {
    emitDiagnostic(
      sink,
      event(
        DiagnosticResult.failed,
        error is TrustedCallerFailure
            ? error.code
            : error is TimeoutException
            ? 'SDK_TIMEOUT'
            : 'SDK_UNKNOWN',
      ),
    );
    rethrow;
  }
}
