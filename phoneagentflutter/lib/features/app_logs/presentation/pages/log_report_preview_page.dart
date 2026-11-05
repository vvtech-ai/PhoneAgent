import 'package:flutter/material.dart';
import '../../../../core/diagnostics/diagnostic_event.dart';
import '../../../../core/diagnostics/diagnostic_journal.dart';
import '../../data/zip_log_repository.dart';
import 'log_report_page.dart';

class LogReportPreviewPage extends StatefulWidget {
  const LogReportPreviewPage({super.key, this.failUpload = false});
  final bool failUpload;
  @override
  State<LogReportPreviewPage> createState() => _LogReportPreviewPageState();
}

class _LogReportPreviewPageState extends State<LogReportPreviewPage> {
  late final _journal = DiagnosticJournal(_MemoryStore());
  bool _failed = false;
  late final _repository = ZipLogRepository(
    _journal,
    uploadBundle: (_) async {
      await Future<void>.delayed(const Duration(milliseconds: 400));
      if (widget.failUpload && !_failed) {
        _failed = true;
        throw StateError('Synthetic upload failure');
      }
    },
  );
  @override
  void initState() {
    super.initState();
    _journal.record(
      DiagnosticEvent(
        operation: DiagnosticOperation.agentStream,
        result: DiagnosticResult.succeeded,
        elapsedMs: 120,
      ),
    );
  }

  @override
  void dispose() {
    _journal.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      LogReportPage(repository: _repository, preview: true);
}

class _MemoryStore implements DiagnosticStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String text) async {
    value = text;
  }
}
