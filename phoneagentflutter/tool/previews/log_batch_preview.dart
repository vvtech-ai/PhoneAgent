import 'dart:typed_data';
import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:phone_agent/features/app_logs/domain/app_log_report.dart';
import 'package:phone_agent/features/app_logs/presentation/pages/log_report_page.dart';

/// Isolated browser UI check. No providers, account, storage or HTTP adapters.
void main() => runApp(
  MaterialApp(
    home: Center(
      child: SizedBox(
        width: 390,
        child: LogReportPage(repository: _BatchPreview(), preview: true),
      ),
    ),
  ),
);

class _BatchPreview implements AppLogRepository {
  int _acknowledged = 0;

  @override
  Future<AppLogBundle> prepare() async {
    final count = _acknowledged == 0 ? 34 : 17;
    final data = utf8.encode(
      List.filled(count, '{"synthetic":true}').join('\n'),
    );
    final zip = ZipEncoder().encode(
      Archive()..addFile(ArchiveFile('diagnostics.jsonl', data.length, data)),
    )!;
    return AppLogBundle(
      watermark: _acknowledged + 1,
      count: count,
      bytes: Uint8List.fromList(zip),
      fileName: 'phoneagent-diagnostics-1.zip',
      hasMore: _acknowledged == 0,
    );
  }

  @override
  Future<void> upload(AppLogBundle bundle) async {
    // No real upload. The synthetic archive is never written to storage.
  }

  @override
  Future<void> acknowledge(AppLogBundle bundle) async {
    _acknowledged = bundle.watermark;
  }
}
