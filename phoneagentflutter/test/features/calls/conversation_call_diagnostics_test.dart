import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/calls/presentation/controller/conversation_call_diagnostics.dart';

void main() {
  test('INFO call result tracing omits per-read pending noise', () {
    final output = <String>[];
    runZoned(
      () {
        traceConversationCallResult(
          'CALL_RESULT_SYNC',
          'pending_try_1',
          sessionId: 'session',
          taskId: 'task',
          callAttemptId: 'attempt',
        );
        traceConversationCallResult(
          'CALL_RESULT_SYNC',
          'failed_timeout',
          sessionId: 'session',
          taskId: 'task',
          callAttemptId: 'attempt',
        );
      },
      zoneSpecification: ZoneSpecification(
        print: (self, parent, zone, line) => output.add(line),
      ),
    );
    expect(output, hasLength(1));
    expect(output.single, contains('failed_timeout'));
  });
}
