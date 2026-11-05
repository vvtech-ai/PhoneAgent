import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/diagnostics/diagnostic_archive.dart';
import 'package:phone_agent/core/diagnostics/diagnostic_archive_files.dart';
import 'package:phone_agent/core/diagnostics/diagnostic_event.dart';
import 'package:phone_agent/core/diagnostics/diagnostic_agent_details.dart';
import 'package:phone_agent/core/diagnostics/diagnostic_journal.dart';
import 'package:phone_agent/features/app_logs/data/diagnostic_journal_factory_io.dart';
import 'package:phone_agent/features/app_logs/data/directory_diagnostic_files.dart';
import 'package:phone_agent/features/app_logs/data/secure_diagnostic_store.dart';
import 'package:phone_agent/features/app_logs/data/zip_log_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late _LegacyStore legacy;
  late _FaultFiles files;
  late DiagnosticArchive archive;
  late DiagnosticJournal journal;
  DiagnosticEvent event(int number) => DiagnosticEvent(
    operation: DiagnosticOperation.accountRequest,
    result: DiagnosticResult.succeeded,
    elapsedMs: number,
  );
  setUp(() async {
    root = await Directory.systemTemp.createTemp('phoneagent-journal-test-');
    legacy = _LegacyStore();
    files = _FaultFiles(DirectoryDiagnosticFiles(root, 'synthetic'));
    archive = DiagnosticArchive(files);
    journal = DiagnosticJournal.archived(
      () async => archive,
      legacyStore: legacy,
      minimumLevel: DiagnosticLogLevel.debug,
    );
  });
  tearDown(() async {
    journal.close();
    await journal.flush();
    await root.delete(recursive: true);
  });

  test(
    'Agent ledger sequence survives files and cannot replace upload watermark',
    () async {
      final received = DiagnosticEvent(
        operation: DiagnosticOperation.agentEvent,
        result: DiagnosticResult.received,
        agent: const DiagnosticAgentDetails(
          frame: DiagnosticAgentFrame.committed,
          ledger: DiagnosticAgentLedger.toolRequested,
          tool: DiagnosticAgentTool.lookupContact,
          sequence: 42,
        ),
      );
      journal.record(received);
      await journal.flush();
      journal.close();
      journal = DiagnosticJournal.archived(
        () async => DiagnosticArchive(files),
        legacyStore: legacy,
      );
      final repository = ZipLogRepository(
        journal,
        uploadBundle: (_) async => fail('Must not upload'),
      );
      final bundle = await repository.prepare();
      expect(bundle.watermark, 1);
      final text = utf8.decode(
        ZipDecoder()
                .decodeBytes(bundle.bytes, verify: true)
                .files
                .single
                .content
            as List<int>,
      );
      expect(jsonDecode(text), received.toJson());
      journal.record(event(2));
      await repository.acknowledge(bundle);
      expect((await journal.snapshot()).events.single.elapsedMs, 2);
      expect((await journal.snapshot()).watermark, 2);
    },
  );

  test(
    'once-only import commits before clearing old store, restart never resurrects',
    () async {
      legacy.value = jsonEncode({
        'version': 1,
        'events': [
          {'sequence': 3, ...event(1).toJson()},
          {'sequence': 9, ...event(2).toJson()},
        ],
      });
      journal.record(event(3));
      expect((await journal.snapshot()).events.map((e) => e.elapsedMs), [
        1,
        2,
        3,
      ]);
      expect((jsonDecode(legacy.value!)['events'] as List), isEmpty);
      await journal.acknowledge(3);
      journal.close();
      await journal.flush();
      // Simulate a retained old slot after a previous process died before clearing.
      legacy.value = jsonEncode({
        'version': 1,
        'events': [
          {'sequence': 3, ...event(1).toJson()},
        ],
      });
      journal = DiagnosticJournal.archived(
        () async => DiagnosticArchive(files),
        legacyStore: legacy,
      );
      journal.record(event(4));
      expect((await journal.snapshot()).events.single.elapsedMs, 4);
      expect((await journal.snapshot()).watermark, 4);
    },
  );

  test(
    'legacy clear failure retries only clear, not duplicate import',
    () async {
      legacy.value = jsonEncode({
        'version': 1,
        'events': [
          {'sequence': 7, ...event(1).toJson()},
        ],
      });
      legacy.failWrite = true;
      journal.record(event(2));
      await expectLater(journal.snapshot(), throwsStateError);
      expect((await archive.snapshot()).events.single.elapsedMs, 1);
      expect(await archive.legacyImported, isTrue);
      legacy.failWrite = false;
      expect((await journal.snapshot()).events.map((e) => e.elapsedMs), [1, 2]);
    },
  );

  test('old read or import commit failure preserves old slot', () async {
    legacy.value = jsonEncode({
      'version': 1,
      'events': [
        {'sequence': 1, ...event(1).toJson()},
      ],
    });
    legacy.failRead = true;
    await expectLater(journal.snapshot(), throwsStateError);
    expect(legacy.writes, 0);
    legacy.failRead = false;
    files.failIndex = true;
    await expectLater(journal.snapshot(), throwsStateError);
    expect(legacy.writes, 0);
    files.failIndex = false;
    expect((await journal.snapshot()).events.single.elapsedMs, 1);
  });

  test(
    'failed in-flight batch survives new events without duplication',
    () async {
      await journal.flush();
      journal.record(event(1));
      files.failIndex = true;
      await expectLater(journal.flush(), throwsStateError);
      journal.record(event(2));
      files.failIndex = false;
      expect((await journal.snapshot()).events.map((e) => e.elapsedMs), [1, 2]);
    },
  );

  test(
    'events arriving during blocked append are not removed with in-flight batch',
    () async {
      await journal.flush();
      final gate = Completer<void>();
      files.blockChunk = gate.future;
      journal.record(event(1));
      final flush = journal.flush();
      await files.chunkStarted.future;
      journal.record(event(2));
      gate.complete();
      await flush;
      expect((await journal.snapshot()).events.map((e) => e.elapsedMs), [1, 2]);
    },
  );

  test(
    'archive retains over 256 across batches and close rejects later records',
    () async {
      for (var i = 0; i < 4; i++) {
        for (var n = 0; n < 100; n++) {
          journal.record(event(i * 100 + n));
        }
        await journal.flush();
      }
      expect((await journal.snapshot()).events, hasLength(400));
      journal.record(event(999));
      journal.close();
      journal.record(event(1000));
      await journal.flush();
      expect((await archive.snapshot()).events.last.elapsedMs, 999);
    },
  );

  test(
    'bounded ZIP batches acknowledge exactly their own rows, no automatic upload',
    () async {
      for (var i = 0; i < 8; i++) {
        journal.record(event(i));
      }
      var uploads = 0;
      final repository = ZipLogRepository(
        journal,
        maxPlainBytes: 350,
        uploadBundle: (_) async {
          uploads++;
        },
      );
      final collected = <int>[];
      var batches = 0;
      while (true) {
        final bundle = await repository.prepare();
        final zip = ZipDecoder().decodeBytes(bundle.bytes);
        final text = utf8.decode(zip.files.single.content as List<int>);
        collected.addAll(
          const LineSplitter()
              .convert(text)
              .map((line) => jsonDecode(line)['elapsedMs'] as int),
        );
        expect(uploads, batches);
        await repository.upload(bundle);
        await repository.acknowledge(bundle);
        batches++;
        if (!bundle.hasMore) break;
      }
      expect(collected, List.generate(8, (i) => i));
      expect(batches, greaterThan(1));
      expect((await journal.snapshot()).events, isEmpty);
    },
  );

  test(
    'production file factory encrypts and bridges existing secure store',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      const scope = 'dev|synthetic-api|factory-owner';
      await SecureDiagnosticStore(scope).write(
        jsonEncode({
          'version': 1,
          'events': [
            {'sequence': 1, ...event(12).toJson()},
          ],
        }),
      );
      final subject = createFileDiagnosticJournal(
        scope,
        root: () async => root,
        allowDebugRead: false,
      );
      subject.record(event(13));
      try {
        expect((await subject.snapshot()).events.map((e) => e.elapsedMs), [
          12,
          13,
        ]);
        final disk = DirectoryDiagnosticFiles(root, scope);
        expect(await disk.read('index.json'), startsWith('v1.'));
        final restarted = createFileDiagnosticJournal(
          scope,
          root: () async => root,
          allowDebugRead: false,
        );
        expect((await restarted.snapshot()).events, hasLength(2));
        restarted.close();
        await restarted.flush();
      } finally {
        subject.close();
        await subject.flush();
      }
    },
  );
}

class _LegacyStore implements DiagnosticStore {
  String? value;
  bool failRead = false, failWrite = false;
  int writes = 0;
  @override
  Future<String?> read() async {
    if (failRead) throw StateError('synthetic read failure');
    return value;
  }

  @override
  Future<void> write(String text) async {
    writes++;
    if (failWrite) throw StateError('synthetic clear failure');
    value = text;
  }
}

class _FaultFiles implements DiagnosticArchiveFiles {
  _FaultFiles(this.delegate);
  final DiagnosticArchiveFiles delegate;
  bool failIndex = false;
  Future<void>? blockChunk;
  final chunkStarted = Completer<void>();
  @override
  Future<T> transaction<T>(Future<T> Function() action) =>
      delegate.transaction(action);
  @override
  Future<String?> read(String name) => delegate.read(name);
  @override
  Future<List<String>> names() => delegate.names();
  @override
  Future<void> remove(String name) => delegate.remove(name);
  @override
  Future<void> replace(String name, String value) async {
    if (name == 'index.json' && failIndex) {
      throw StateError('synthetic commit failure');
    }
    if (name.endsWith('.jsonl') && blockChunk != null) {
      if (!chunkStarted.isCompleted) chunkStarted.complete();
      await blockChunk;
    }
    await delegate.replace(name, value);
  }
}
