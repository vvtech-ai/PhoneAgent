import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/diagnostics/diagnostic_event.dart';
import 'package:phone_agent/features/trusted_caller/data/trusted_caller_diagnostics.dart';
import 'package:phone_agent/features/trusted_caller/domain/trusted_caller.dart';

void main() {
  test('native initialization categories survive diagnostic roundtrip', () {
    for (final code in [
      'SDK_RUNTIME_MISSING',
      'SDK_RUNTIME_LINKAGE_FAILED',
      'SDK_INITIALIZATION_EXCEPTION',
    ]) {
      final details = DiagnosticTrustedCallerDetails(
        DiagnosticTrustedCallerStage.prepare,
        DiagnosticTrustedCallerPlatform.android,
        DiagnosticTrustedCallerEnvironment.test,
        code: code,
      );
      expect(
        DiagnosticTrustedCallerDetails.fromJson(details.toJson()).code,
        code,
      );
    }
  });
  test(
    'records stage failure and roundtrips only fixed safe metadata',
    () async {
      final events = <DiagnosticEvent>[];
      await expectLater(
        traceTrustedCaller<void>(
          stage: DiagnosticTrustedCallerStage.prepare,
          environment: 'test',
          sink: events.add,
          action: () async =>
              throw const TrustedCallerFailure('SDK_SIM_CLEANUP_UNCONFIRMED'),
        ),
        throwsA(isA<TrustedCallerFailure>()),
      );
      expect(events.map((e) => e.result), [
        DiagnosticResult.started,
        DiagnosticResult.failed,
      ]);
      final restored = DiagnosticEvent.fromJson(events.last.toJson());
      expect(restored.trustedCaller!.code, 'SDK_SIM_CLEANUP_UNCONFIRMED');
      expect(
        restored.trustedCaller!.stage,
        DiagnosticTrustedCallerStage.prepare,
      );
      const unsafe = DiagnosticTrustedCallerDetails(
        DiagnosticTrustedCallerStage.open,
        DiagnosticTrustedCallerPlatform.android,
        DiagnosticTrustedCallerEnvironment.test,
        code: 'synthetic-sensitive-native-message',
      );
      expect(unsafe.toJson()['code'], 'SDK_UNKNOWN');
      expect(unsafe.toJson().toString(), isNot(contains('sensitive')));
    },
  );
}
