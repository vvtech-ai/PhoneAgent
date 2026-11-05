import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_agent/app/business_providers.dart';
import 'package:phone_agent/app/diagnostics_providers.dart';
import 'package:phone_agent/core/diagnostics/diagnostic_event.dart';
import 'package:phone_agent/core/diagnostics/diagnostic_journal.dart';
import 'package:phone_agent/features/app_logs/data/zip_log_repository.dart';
import 'package:phone_agent/features/app_logs/domain/app_log_report.dart';

final shellLogReportProvider = Provider<ShellLogReport>((ref) {
  ref.watch(loginEpochProvider);
  final journal = ref.watch(diagnosticJournalProvider);
  final repository = ShellLogReport(journal);
  ref.onDispose(repository.close);
  return repository;
});

/// Synthetic failures exercise the actual ZIP, page and retry controller.
/// Kept for one login, not reset on each navigation into the settings page.
class ShellLogReport implements AppLogRepository {
  ShellLogReport(DiagnosticJournal journal)
    : _zip = ZipLogRepository(journal, uploadBundle: (_) async {}) {
    journal.record(
      DiagnosticEvent(
        operation: DiagnosticOperation.agentStream,
        result: DiagnosticResult.succeeded,
        elapsedMs: 120,
      ),
    );
  }
  final ZipLogRepository _zip;
  int uploads = 0, cleanups = 0;
  bool _closed = false;
  AppLogBundle? lastUpload;

  void _check() {
    if (_closed) throw StateError('MOCK log scope closed');
  }

  @override
  Future<AppLogBundle> prepare() async {
    _check();
    final result = await _zip.prepare();
    _check();
    return result;
  }

  @override
  Future<void> upload(AppLogBundle bundle) async {
    _check();
    uploads++;
    lastUpload = bundle;
    if (uploads == 1) throw StateError('MOCK upload failure');
    // No network, files, platform ports or account client in this implementation.
  }

  @override
  Future<void> acknowledge(AppLogBundle bundle) async {
    _check();
    cleanups++;
    if (cleanups == 1) throw StateError('MOCK cleanup failure');
    await _zip.acknowledge(bundle);
  }

  void close() => _closed = true;
}
