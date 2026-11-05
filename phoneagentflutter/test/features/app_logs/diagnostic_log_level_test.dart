import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/diagnostics/diagnostic_agent_details.dart';
import 'package:phone_agent/core/diagnostics/diagnostic_event.dart';
import 'package:phone_agent/core/diagnostics/diagnostic_journal.dart';

void main() {
  test(
    'default journal drops per-frame detail and preserves failures',
    () async {
      final journal = DiagnosticJournal(_Store());
      addTearDown(journal.close);
      for (var index = 0; index < 300; index++) {
        journal.record(
          DiagnosticEvent(
            operation: DiagnosticOperation.agentEvent,
            result: DiagnosticResult.received,
          ),
        );
        journal.record(
          DiagnosticEvent(
            operation: DiagnosticOperation.voiceMedia,
            result: DiagnosticResult.received,
          ),
        );
      }
      journal.record(
        DiagnosticEvent(
          operation: DiagnosticOperation.agentSignal,
          result: DiagnosticResult.received,
        ),
      );
      journal.record(
        DiagnosticEvent(
          operation: DiagnosticOperation.agentEvent,
          result: DiagnosticResult.failed,
        ),
      );

      final recorded = (await journal.snapshot()).events;
      expect(recorded.map((event) => event.operation), [
        DiagnosticOperation.agentSignal,
        DiagnosticOperation.agentEvent,
      ]);
      expect(recorded.last.result, DiagnosticResult.failed);
    },
  );

  test('DEBUG includes detail while ERROR retains only failures', () async {
    final detail = DiagnosticEvent(
      operation: DiagnosticOperation.agentEvent,
      result: DiagnosticResult.received,
    );
    final failed = DiagnosticEvent(
      operation: DiagnosticOperation.agentEvent,
      result: DiagnosticResult.failed,
    );
    final debug = DiagnosticJournal(
      _Store(),
      minimumLevel: DiagnosticLogLevel.debug,
    );
    final error = DiagnosticJournal(
      _Store(),
      minimumLevel: DiagnosticLogLevel.error,
    );
    addTearDown(debug.close);
    addTearDown(error.close);
    for (final journal in [debug, error]) {
      journal.record(detail);
      journal.record(failed);
    }
    expect((await debug.snapshot()).events, [detail, failed]);
    expect((await error.snapshot()).events, [failed]);
  });

  test(
    'INFO retains a final response while dropping per-frame events',
    () async {
      final journal = DiagnosticJournal(_Store());
      addTearDown(journal.close);
      journal.record(
        DiagnosticEvent(
          operation: DiagnosticOperation.agentEvent,
          result: DiagnosticResult.received,
          agent: DiagnosticAgentDetails(frame: DiagnosticAgentFrame.toolStart),
        ),
      );
      journal.record(
        DiagnosticEvent(
          operation: DiagnosticOperation.agentEvent,
          result: DiagnosticResult.received,
          agent: DiagnosticAgentDetails(
            frame: DiagnosticAgentFrame.finalResponse,
          ),
        ),
      );
      final recorded = (await journal.snapshot()).events;
      expect(recorded.length, 1);
      expect(recorded.single.agent?.frame, DiagnosticAgentFrame.finalResponse);
    },
  );

  test('invalid level falls back to INFO rather than enabling detail', () {
    expect(DiagnosticLogLevel.parse('debug'), DiagnosticLogLevel.debug);
    expect(DiagnosticLogLevel.parse(' warn '), DiagnosticLogLevel.warn);
    expect(DiagnosticLogLevel.parse('UNKNOWN'), DiagnosticLogLevel.info);
  });
}

class _Store implements DiagnosticStore {
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String text) async => value = text;
}
