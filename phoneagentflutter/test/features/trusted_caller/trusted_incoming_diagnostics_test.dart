import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/diagnostics/diagnostic_event.dart';
import 'package:phone_agent/features/trusted_caller/data/trusted_incoming_diagnostics.dart';

void main() {
  test(
    'fixed native metadata is recorded without identity or secret fields',
    () {
      final events = <DiagnosticEvent>[];
      final trace = TrustedIncomingDiagnostics(events.add, 'test');
      final value = {
        'diagnostic': {
          'stage': 'incomingVerify',
          'result': 'succeeded',
          'code': 'IOS_VERIFY_SUCCEEDED',
          'timeMs': 1700000000000,
          'token': 'synthetic-private',
          'name': 'synthetic-private',
        },
      };
      expect(trace.consume(value), true);
      expect(
        events.single.trustedCaller?.stage,
        DiagnosticTrustedCallerStage.incomingVerify,
      );
      expect(
        events.single.toJson().toString(),
        isNot(contains('synthetic-private')),
      );
      expect(events.single.time.millisecondsSinceEpoch, 1700000000000);
      for (final key in ['stage', 'result', 'code', 'timeMs']) {
        final invalid = Map<String, Object>.from(value['diagnostic']!);
        invalid[key] = 'private';
        expect(trace.consume({'diagnostic': invalid}), true);
      }
      expect(events, hasLength(1));
      expect(trace.consume({'identity': {}}), false);
    },
  );
}
