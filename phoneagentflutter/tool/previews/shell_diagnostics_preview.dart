import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_agent/app/business_providers.dart';
import 'package:phone_agent/app/diagnostics_providers.dart';
import 'package:phone_agent/app/log_report_providers.dart';
import 'package:phone_agent/core/diagnostics/diagnostic_journal.dart';
import 'shell_log_report_preview.dart';

/// Preserve journal behavior without letting MOCK lifecycle flushes reach the
/// real keychain/preferences. Each synthetic login owns a separate journal.
List<Override> shellDiagnosticsOverrides() => [
  logReportRepositoryProvider.overrideWith(
    (ref) => ref.watch(shellLogReportProvider),
  ),
  diagnosticJournalProvider.overrideWith((ref) {
    ref.watch(loginEpochProvider);
    final journal = DiagnosticJournal(_MemoryDiagnosticStore());
    ref.onDispose(journal.close);
    return journal;
  }),
];

class _MemoryDiagnosticStore implements DiagnosticStore {
  String? _value;
  @override
  Future<String?> read() async => _value;
  @override
  Future<void> write(String value) async => _value = value;
}
