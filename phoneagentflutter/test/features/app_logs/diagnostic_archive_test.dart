import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/diagnostics/diagnostic_archive.dart';
import 'package:phone_agent/core/diagnostics/diagnostic_archive_files.dart';
import 'package:phone_agent/core/diagnostics/diagnostic_event.dart';
import 'package:phone_agent/features/app_logs/data/directory_diagnostic_files.dart';

void main() {
  late Directory root;
  late DirectoryDiagnosticFiles files;
  late DateTime now;
  late DiagnosticArchive archive;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('phoneagent-archive-test-');
    files = DirectoryDiagnosticFiles(root, 'synthetic-env|api|owner-a');
    now = DateTime(2026, 9, 20, 10);
    archive = DiagnosticArchive(files, clock: () => now);
  });
  tearDown(() async {
    // Only this test's OS-created temporary directory; never a supplied path.
    await root.delete(recursive: true);
  });

  DiagnosticEvent event(int value) => DiagnosticEvent(
    operation: DiagnosticOperation.accountRequest,
    result: DiagnosticResult.succeeded,
    elapsedMs: value,
    time: now,
    sessionId: 'not-a-uuid-private-phone',
    traceId: 'secret-token',
  );

  test(
    'more than 256 events persist across recreation with privacy whitelist',
    () async {
      for (var i = 0; i < 4; i++) {
        await archive.append(List.generate(100, (n) => event(i * 100 + n)));
      }
      final restarted = DiagnosticArchive(files, clock: () => now);
      final result = await restarted.snapshot();
      expect(result.watermark, 400);
      expect(
        result.events.map((e) => e.elapsedMs),
        List.generate(400, (n) => n),
      );
      expect(
        result.events.every((e) => e.sessionId.isEmpty && e.traceId.isEmpty),
        isTrue,
      );
      final names = await files.names();
      expect(names.where((e) => e.endsWith('.jsonl')), hasLength(1));
      expect(
        await files.read(names.singleWhere((e) => e.endsWith('.jsonl'))),
        isNot(contains('secret')),
      );
    },
  );

  test(
    'rolling size limit rewrites current chunk and opens a new one',
    () async {
      final lineBytes = utf8
          .encode('${jsonEncode({'sequence': 1, ...event(1).toJson()})}\n')
          .length;
      archive = DiagnosticArchive(
        files,
        clock: () => now,
        maxFileBytes: lineBytes * 2,
      );
      await archive.append([event(1)]);
      await archive.append([event(2)]);
      await archive.append([event(3)]);
      final result = await archive.snapshot();
      expect(result.events.map((e) => e.elapsedMs), [1, 2, 3]);
      final chunks = (await files.names()).where((e) => e.endsWith('.jsonl'));
      expect(chunks, hasLength(2));
      for (final name in chunks) {
        expect(
          utf8.encode((await files.read(name))!).length,
          lessThanOrEqualTo(lineBytes * 2),
        );
      }
    },
  );

  test('oversized batch fails without committing any events', () async {
    archive = DiagnosticArchive(files, clock: () => now, maxFileBytes: 400);
    await archive.append([event(1)]);
    await expectLater(
      archive.append(List.generate(10, event)),
      throwsStateError,
    );
    expect((await archive.snapshot()).events.map((e) => e.elapsedMs), [1]);
  });

  test(
    'calendar retention includes today and 14 preceding days, not 256 rows',
    () async {
      for (var day = 1; day <= 20; day++) {
        now = DateTime(2026, 9, day, 23, 59);
        await archive.append([event(day)]);
      }
      final result = await archive.snapshot();
      expect(
        result.events.map((e) => e.elapsedMs),
        List.generate(15, (i) => i + 6),
      );
      expect(result.watermark, 20);
      expect(
        (await files.names()).where((e) => e.endsWith('.jsonl')),
        hasLength(15),
      );
    },
  );

  test(
    'month/year boundary and clock rollback preserve future-dated files',
    () async {
      now = DateTime(2025, 12, 31, 23, 59);
      await archive.append([event(1)]);
      now = DateTime(2026, 1, 14);
      await archive.append([event(2)]);
      expect((await archive.snapshot()).events, hasLength(2));
      now = DateTime(2026, 1, 15);
      expect((await archive.snapshot()).events.map((e) => e.elapsedMs), [2]);
      now = DateTime(2026, 1, 1);
      await archive.append([event(3)]);
      expect((await archive.snapshot()).events.map((e) => e.elapsedMs), [2, 3]);
    },
  );

  test(
    'retention uses write date, independently from UTC event timestamp',
    () async {
      now = DateTime(2026, 9, 20, 0, 1);
      await archive.append([
        DiagnosticEvent(
          operation: DiagnosticOperation.agentSignal,
          result: DiagnosticResult.failed,
          time: DateTime.utc(2026, 9, 19, 16, 1),
        ),
      ]);
      expect(
        (await files.names()).any((name) => name.startsWith('log-2026-09-20-')),
        isTrue,
      );
      expect(
        (await archive.snapshot()).events.single.time,
        DateTime.utc(2026, 9, 19, 16, 1),
      );
    },
  );

  test(
    'acknowledge preserves later events and never reuses sequence after restart',
    () async {
      await archive.append([event(1)]);
      final uploaded = await archive.snapshot();
      await archive.append([event(2)]);
      await archive.acknowledge(uploaded.watermark);
      expect((await archive.snapshot()).events.map((e) => e.elapsedMs), [2]);
      await archive.acknowledge(2);
      archive = DiagnosticArchive(files, clock: () => now);
      await archive.append([event(3)]);
      await archive.acknowledge(uploaded.watermark);
      expect((await archive.snapshot()).watermark, 3);
      expect((await archive.snapshot()).events.single.elapsedMs, 3);
      await expectLater(archive.acknowledge(4), throwsArgumentError);
      await expectLater(archive.acknowledge(-1), throwsArgumentError);
    },
  );

  test('expiry of every file keeps sequence cursor persistent', () async {
    await archive.append([event(1), event(2)]);
    now = DateTime(2027, 1, 1);
    expect((await archive.snapshot()).events, isEmpty);
    archive = DiagnosticArchive(files, clock: () => now);
    await archive.append([event(3)]);
    expect((await archive.snapshot()).watermark, 3);
  });

  test(
    'account scopes and unknown files are never collected together',
    () async {
      final other = DiagnosticArchive(
        DirectoryDiagnosticFiles(root, 'other-owner'),
        clock: () => now,
      );
      await other.append([event(99)]);
      await archive.append([event(1)]);
      final unknown = File('${files.directory.path}/user-notes.txt');
      await unknown.writeAsString('synthetic unrelated content');
      await archive.acknowledge(1);
      expect(await unknown.readAsString(), 'synthetic unrelated content');
      expect((await other.snapshot()).events.single.elapsedMs, 99);
      expect(files.directory.path, isNot(contains('owner-a')));
    },
  );

  test(
    'instances targeting same normalized directory serialize concurrent appends',
    () async {
      final second = DiagnosticArchive(
        DirectoryDiagnosticFiles(
          Directory('${root.path}/.'),
          'synthetic-env|api|owner-a',
        ),
        clock: () => now,
      );
      await Future.wait(
        List.generate(
          24,
          (i) => (i.isEven ? archive : second).append([event(i)]),
        ),
      );
      final result = await archive.snapshot();
      expect(result.watermark, 24);
      expect(
        result.events.map((e) => e.elapsedMs).toSet(),
        List.generate(24, (i) => i).toSet(),
      );
    },
  );

  test(
    'chunk write failure leaves previous snapshot intact and can retry',
    () async {
      await archive.append([event(1)]);
      final failing = _FaultFiles(files)..failChunk = true;
      final subject = DiagnosticArchive(failing, clock: () => now);
      await expectLater(subject.append([event(2)]), throwsStateError);
      expect((await archive.snapshot()).events.single.elapsedMs, 1);
      failing.failChunk = false;
      await subject.append([event(2)]);
      expect((await subject.snapshot()).events.map((e) => e.elapsedMs), [1, 2]);
    },
  );

  test(
    'index commit failure leaves orphan excluded, retry includes batch only once',
    () async {
      await archive.append([event(1)]);
      final failing = _FaultFiles(files)..failIndex = true;
      final subject = DiagnosticArchive(failing, clock: () => now);
      await expectLater(subject.append([event(2)]), throwsStateError);
      expect((await archive.snapshot()).events.single.elapsedMs, 1);
      failing.failIndex = false;
      await subject.append([event(2)]);
      expect((await subject.snapshot()).events.map((e) => e.elapsedMs), [1, 2]);
    },
  );

  test(
    'cleanup failure cannot report an already committed append as failed',
    () async {
      await archive.append([event(1)]);
      final failing = _FaultFiles(files)..failDelete = true;
      final subject = DiagnosticArchive(failing, clock: () => now);
      await subject.append([event(2)]);
      await expectLater(subject.snapshot(), throwsStateError);
      failing.failDelete = false;
      expect((await subject.snapshot()).events.map((e) => e.elapsedMs), [1, 2]);
    },
  );

  test(
    'cleanup failure after ack keeps tombstone and retry is idempotent',
    () async {
      await archive.append([event(1)]);
      final failing = _FaultFiles(files)..failDelete = true;
      final subject = DiagnosticArchive(failing, clock: () => now);
      await expectLater(subject.acknowledge(1), throwsStateError);
      failing.failDelete = false;
      await subject.acknowledge(1);
      expect((await archive.snapshot()).events, isEmpty);
      await archive.append([event(2)]);
      expect((await archive.snapshot()).watermark, 2);
    },
  );

  test(
    'corrupt or missing index refuses to replace existing archive',
    () async {
      await archive.append([event(1)]);
      final original = await files.read('index.json');
      await files.replace('index.json', '{"version":999}');
      await expectLater(archive.append([event(2)]), throwsFormatException);
      expect(await files.read('index.json'), '{"version":999}');
      await files.remove('index.json');
      await expectLater(archive.snapshot(), throwsFormatException);
      await files.replace('index.json', original!);
      expect((await archive.snapshot()).events.single.elapsedMs, 1);
    },
  );

  test(
    'corrupt data blocks snapshot and copy-on-write instead of being replaced',
    () async {
      await archive.append([event(1)]);
      final name = (await files.names()).singleWhere(
        (e) => e.endsWith('.jsonl'),
      );
      await files.replace(name, 'corrupted\n');
      final before = await files.read('index.json');
      await expectLater(archive.snapshot(), throwsFormatException);
      await expectLater(archive.append([event(2)]), throwsFormatException);
      expect(await files.read('index.json'), before);
      expect(await files.read(name), 'corrupted\n');
    },
  );

  test('directory port rejects traversal and non-regular files', () async {
    await archive.snapshot();
    await expectLater(
      files.replace('../escape', 'private'),
      throwsArgumentError,
    );
    await expectLater(files.remove('not-owned.txt'), throwsArgumentError);
    await files.remove('index.json');
    await Directory('${files.directory.path}/index.json').create();
    await expectLater(archive.snapshot(), throwsA(isA<FileSystemException>()));
  });

  test(
    'default five MiB boundary rotates real files without truncation',
    () async {
      final batch = List.generate(20000, event);
      await archive.append(batch);
      await archive.append(batch);
      final result = await archive.snapshot();
      expect(result.events, hasLength(40000));
      expect(result.watermark, 40000);
      final chunks = (await files.names()).where(
        (name) => name.endsWith('.jsonl'),
      );
      expect(chunks, hasLength(2));
      for (final name in chunks) {
        expect(
          await File('${files.directory.path}/$name').length(),
          lessThanOrEqualTo(5242880),
        );
      }
    },
  );

  test('first failed index commit can restart and retry safely', () async {
    await archive.snapshot();
    final failing = _FaultFiles(files)..failIndex = true;
    final subject = DiagnosticArchive(failing, clock: () => now);
    await expectLater(subject.append([event(1)]), throwsStateError);
    final restarted = DiagnosticArchive(files, clock: () => now);
    expect((await restarted.snapshot()).events, isEmpty);
    await restarted.append([event(1)]);
    expect((await restarted.snapshot()).watermark, 1);
  });

  test(
    'actual pending-file obstruction leaves index and old events intact',
    () async {
      await archive.append([event(1)]);
      final pending = Directory('${files.directory.path}/index.json.pending');
      await pending.create();
      await expectLater(
        archive.append([event(2)]),
        throwsA(isA<FileSystemException>()),
      );
      expect((await archive.snapshot()).events.single.elapsedMs, 1);
      await pending.delete();
      await archive.append([event(2)]);
      expect((await archive.snapshot()).events.map((e) => e.elapsedMs), [1, 2]);
    },
  );

  test('empty append creates no data and invalid size fails early', () async {
    // transaction may create the namespace, but no index or payload is written.
    await archive.append([]);
    expect(await files.names(), isEmpty);
    expect(
      () => DiagnosticArchive(files, maxFileBytes: 0),
      throwsArgumentError,
    );
    expect(
      () => DiagnosticArchive(files, maxFileBytes: 5242881),
      throwsArgumentError,
    );
  });
}

class _FaultFiles implements DiagnosticArchiveFiles {
  _FaultFiles(this.delegate);
  final DiagnosticArchiveFiles delegate;
  bool failChunk = false, failIndex = false, failDelete = false;
  @override
  Future<T> transaction<T>(Future<T> Function() action) =>
      delegate.transaction(action);
  @override
  Future<String?> read(String name) => delegate.read(name);
  @override
  Future<List<String>> names() => delegate.names();
  @override
  Future<void> replace(String name, String value) async {
    if ((failIndex && name == 'index.json') ||
        (failChunk && name.endsWith('.jsonl'))) {
      throw StateError('synthetic write failure');
    }
    await delegate.replace(name, value);
  }

  @override
  Future<void> remove(String name) async {
    if (failDelete) throw StateError('synthetic cleanup failure');
    await delegate.remove(name);
  }
}
