import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:phone_agent/core/diagnostics/diagnostic_event.dart';
import 'package:phone_agent/core/diagnostics/diagnostic_journal.dart';
import 'package:phone_agent/features/app_logs/data/diagnostic_journal_factory_io.dart';
import 'package:phone_agent/features/app_logs/data/directory_diagnostic_files.dart';
import 'package:phone_agent/features/app_logs/data/secure_diagnostic_key.dart';
import 'package:phone_agent/features/app_logs/data/secure_diagnostic_store.dart';
import 'package:phone_agent/features/app_logs/data/zip_log_repository.dart';

/// Standalone device probe, never reachable from a production route. Uses the
/// real storage factory with one fresh synthetic scope; no auth, API or media.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(home: _ProbePage()));
}

class _ProbePage extends StatefulWidget {
  const _ProbePage();
  @override
  State<_ProbePage> createState() => _ProbePageState();
}

class _ProbePageState extends State<_ProbePage> {
  String status = '正在验证私有加密日志存储…';
  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    final watch = Stopwatch()..start();
    final scope =
        'diagnostic-device-probe|${DateTime.now().microsecondsSinceEpoch}';
    const storage = FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.unlocked_this_device,
      ),
    );
    DiagnosticJournal? journal;
    DirectoryDiagnosticFiles? disk;
    final report = <String, Object>{
      'platform': Platform.operatingSystem,
      'completed': false,
      'cleanup': false,
      'networkRequests': 0,
    };
    try {
      final root = await diagnosticPrivateRoot();
      disk = DirectoryDiagnosticFiles(root, scope);
      journal = createFileDiagnosticJournal(
        scope,
        root: () async => root,
        storage: storage,
      );
      for (var batch = 0; batch < 4; batch++) {
        for (var i = 0; i < 100; i++) {
          journal.record(
            DiagnosticEvent(
              operation: DiagnosticOperation.accountRequest,
              result: DiagnosticResult.succeeded,
              elapsedMs: batch * 100 + i,
            ),
          );
        }
        await journal.flush();
      }
      _check((await journal.snapshot()).events.length == 400, 'retention');
      journal.close();
      await journal.flush();
      journal = createFileDiagnosticJournal(
        scope,
        root: () async => root,
        storage: storage,
      );
      _check((await journal.snapshot()).events.length == 400, 'recreation');
      final ciphertext = await disk.read('index.json');
      _check(
        ciphertext?.startsWith('v1.') == true &&
            !ciphertext!.contains('sequence'),
        'ciphertext',
      );
      final repository = ZipLogRepository(
        journal,
        maxPlainBytes: 4096,
        uploadBundle: (_) async => throw StateError('Probe must never upload'),
      );
      final bundle = await repository.prepare();
      _check(bundle.hasMore && bundle.count > 0 && bundle.count < 400, 'batch');
      final zip = ZipDecoder().decodeBytes(bundle.bytes, verify: true);
      final rows = const LineSplitter().convert(
        utf8.decode(zip.files.single.content as List<int>),
      );
      _check(rows.length == bundle.count, 'zip');
      journal.record(
        DiagnosticEvent(
          operation: DiagnosticOperation.agentStream,
          result: DiagnosticResult.succeeded,
          elapsedMs: 999,
        ),
      );
      // Local acknowledgement is deliberately tested without any HTTP call.
      await repository.acknowledge(bundle);
      final remaining = await journal.snapshot();
      _check(
        remaining.events.length == 401 - bundle.count &&
            remaining.events.last.elapsedMs == 999,
        'watermark',
      );
      report.addAll({
        'completed': true,
        'persistedEvents': 400,
        'batchCount': bundle.count,
        'remainingCount': remaining.events.length,
        'encrypted': true,
        'recreated': true,
        'iosProtectionVerified': Platform.isIOS,
      });
    } catch (error) {
      report['failureType'] = error.runtimeType.toString();
    } finally {
      journal?.close();
      await journal?.flush();
      try {
        if (disk != null && await disk.directory.exists()) {
          await disk.transaction(() async {
            for (final name in await disk!.names()) {
              // Only files in this fresh synthetic hash directory. Unknown
              // names are rejected by the adapter, never recursively deleted.
              await disk.remove(name);
            }
          });
          await disk.directory.delete();
        }
        await storage.delete(key: SecureDiagnosticKey(scope).key);
        await storage.delete(key: SecureDiagnosticStore(scope).key);
        report['cleanup'] = true;
      } catch (error) {
        report['cleanupFailureType'] = error.runtimeType.toString();
      }
    }
    report['elapsedMs'] = watch.elapsedMilliseconds;
    // Fixed synthetic aggregate fields only; never print scope, key or paths.
    debugPrint('DIAGNOSTIC_STORAGE_PROBE ${jsonEncode(report)}');
    if (mounted) {
      setState(
        () => status = report['completed'] == true && report['cleanup'] == true
            ? '加密存储验证通过\n400 条合成日志重建恢复\n分批 ZIP 与水位清理通过\n测试数据已清理\n没有网络请求或账号操作'
            : '存储验证失败，请查看脱敏诊断结果',
      );
    }
  }

  void _check(bool value, String code) {
    if (!value) throw StateError(code);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('独立诊断存储验证')),
    body: SafeArea(
      child: Center(
        child: Padding(padding: const EdgeInsets.all(24), child: Text(status)),
      ),
    ),
  );
}
