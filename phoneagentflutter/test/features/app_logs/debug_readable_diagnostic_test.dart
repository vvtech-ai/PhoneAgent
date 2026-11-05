import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/diagnostics/diagnostic_event.dart';
import 'package:phone_agent/core/diagnostics/diagnostic_archive.dart';
import 'package:phone_agent/core/diagnostics/diagnostic_archive_files.dart';
import 'package:phone_agent/features/app_logs/data/debug_readable_diagnostic_files.dart';
import 'package:phone_agent/features/app_logs/data/diagnostic_journal_factory_io.dart';
import 'package:phone_agent/features/app_logs/data/directory_diagnostic_files.dart';
import 'package:phone_agent/features/app_logs/data/encrypted_diagnostic_files.dart';
import 'package:phone_agent/features/app_logs/data/secure_diagnostic_key.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  const scope = 'test|synthetic-api|debug-owner';
  DiagnosticEvent event(int elapsed) => DiagnosticEvent(
    operation: DiagnosticOperation.voiceMedia,
    result: DiagnosticResult.succeeded,
    elapsedMs: elapsed,
  );
  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    root = await Directory.systemTemp.createTemp('debug-diagnostic-test-');
  });
  tearDown(() => root.delete(recursive: true));

  test(
    'Android Debug exposes readable scoped events while retaining encrypted truth',
    () async {
      final journal = createFileDiagnosticJournal(
        scope,
        root: () async => root,
        platform: TargetPlatform.android,
      );
      journal.record(event(14));
      await journal.flush();
      final canonical = DirectoryDiagnosticFiles(root, scope);
      expect(await canonical.read('index.json'), startsWith('v1.'));
      final raw = DirectoryDiagnosticFiles(
        Directory('${root.path}/readable-debug'),
        scope,
      );
      final names = await raw.names();
      expect(jsonDecode((await raw.read('index.json'))!), isA<Map>());
      final log = names.singleWhere((name) => name.endsWith('.jsonl'));
      expect(jsonDecode((await raw.read(log))!.trim())['elapsedMs'], 14);
      expect(
        await const FlutterSecureStorage().read(
          key: SecureDiagnosticKey(scope).key,
        ),
        isNotNull,
      );
      expect((await journal.snapshot()).events.single.elapsedMs, 14);
      journal.close();
      await journal.flush();
    },
  );

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    test('$platform protected storage remains encrypted', () async {
      final journal = createFileDiagnosticJournal(
        scope,
        root: () async => root,
        platform: platform,
        allowDebugRead: platform != TargetPlatform.android,
      );
      journal.record(event(21));
      await journal.flush();
      final raw = DirectoryDiagnosticFiles(root, scope);
      for (final name in await raw.names()) {
        expect(await raw.read(name), startsWith('v1.'));
      }
      expect((await journal.snapshot()).events.single.elapsedMs, 21);
      journal.close();
      await journal.flush();
    });
  }

  test('old encrypted archive survives readable append and restart', () async {
    final protected = createFileDiagnosticJournal(
      scope,
      root: () async => root,
      platform: TargetPlatform.android,
      allowDebugRead: false,
    );
    protected.record(event(31));
    await protected.flush();
    protected.close();
    await protected.flush();
    final readable = createFileDiagnosticJournal(
      scope,
      root: () async => root,
      platform: TargetPlatform.android,
    );
    expect((await readable.snapshot()).events.single.elapsedMs, 31);
    readable.record(event(32));
    await readable.flush();
    readable.close();
    await readable.flush();
    final reopened = createFileDiagnosticJournal(
      scope,
      root: () async => root,
      platform: TargetPlatform.android,
    );
    final snapshot = await reopened.snapshot();
    expect(snapshot.events.map((e) => e.elapsedMs), [31, 32]);
    expect(snapshot.watermark, 2);
    await reopened.acknowledge(1);
    expect((await reopened.snapshot()).events.single.elapsedMs, 32);
    reopened.close();
    await reopened.flush();
    final protectedAgain = createFileDiagnosticJournal(
      scope,
      root: () async => root,
      platform: TargetPlatform.android,
      allowDebugRead: false,
    );
    expect((await protectedAgain.snapshot()).events.single.elapsedMs, 32);
    expect(
      await DirectoryDiagnosticFiles(
        Directory('${root.path}/readable-debug'),
        scope,
      ).names(),
      isEmpty,
    );
    protectedAgain.close();
    await protectedAgain.flush();
  });

  test(
    'a blocked readable directory never breaks the protected journal',
    () async {
      await File('${root.path}/readable-debug').writeAsString('blocked');
      final journal = createFileDiagnosticJournal(
        scope,
        root: () async => root,
        platform: TargetPlatform.android,
      );
      journal.record(event(37));
      expect((await journal.snapshot()).events.single.elapsedMs, 37);
      final canonical = DirectoryDiagnosticFiles(root, scope);
      expect(await canonical.read('index.json'), startsWith('v1.'));
      journal.close();
      await journal.flush();
    },
  );

  test(
    'missing old encryption key preserves archive instead of overwriting',
    () async {
      final protected = createFileDiagnosticJournal(
        scope,
        root: () async => root,
        platform: TargetPlatform.android,
        allowDebugRead: false,
      );
      protected.record(event(41));
      await protected.flush();
      protected.close();
      await protected.flush();
      final raw = DirectoryDiagnosticFiles(root, scope);
      final before = await raw.read('index.json');
      await const FlutterSecureStorage().delete(
        key: SecureDiagnosticKey(scope).key,
      );
      final readable = createFileDiagnosticJournal(
        scope,
        root: () async => root,
        platform: TargetPlatform.android,
      );
      await expectLater(readable.snapshot(), throwsStateError);
      expect(await raw.read('index.json'), before);
      readable.close();
      await readable.flush();
    },
  );

  test(
    'failed mirror deletion is retried after canonical file is gone',
    () async {
      final mirror = _RemoveFault(
        DirectoryDiagnosticFiles(
          Directory('${root.path}/readable-debug'),
          scope,
        ),
      );
      final files = DebugReadableDiagnosticFiles(
        EncryptedDiagnosticFiles(
          DirectoryDiagnosticFiles(root, scope),
          scope,
          SecureDiagnosticKey(scope).load,
        ),
        mirror,
      );
      final archive = DiagnosticArchive(files);
      await archive.append([event(52)]);
      final logName = (await mirror.names()).singleWhere(
        (n) => n.endsWith('.jsonl'),
      );
      mirror.failRemove = true;
      await archive.acknowledge(1);
      expect(await mirror.read(logName), isNotNull);
      mirror.failRemove = false;
      expect((await archive.snapshot()).events, isEmpty);
      expect(await mirror.read(logName), isNull);
    },
  );
  test(
    'protected storage removes interrupted readable pending files',
    () async {
      final journal = createFileDiagnosticJournal(
        scope,
        root: () async => root,
        platform: TargetPlatform.android,
      );
      journal.record(event(61));
      await journal.flush();
      journal.close();
      await journal.flush();
      final mirror = DirectoryDiagnosticFiles(
        Directory('${root.path}/readable-debug'),
        scope,
      );
      final pending = File(
        '${mirror.directory.path}/log-2000-01-01-998.jsonl.pending',
      );
      await pending.writeAsString('synthetic interrupted diagnostic');
      final protected = createFileDiagnosticJournal(
        scope,
        root: () async => root,
        platform: TargetPlatform.android,
        allowDebugRead: false,
      );
      expect((await protected.snapshot()).events.single.elapsedMs, 61);
      expect(await pending.exists(), isFalse);
      protected.close();
      await protected.flush();
    },
  );
}

class _RemoveFault implements DiagnosticArchiveFiles {
  _RemoveFault(this.delegate);
  final DiagnosticArchiveFiles delegate;
  bool failRemove = false;
  @override
  Future<T> transaction<T>(Future<T> Function() action) =>
      delegate.transaction(action);
  @override
  Future<String?> read(String name) => delegate.read(name);
  @override
  Future<void> replace(String name, String value) =>
      delegate.replace(name, value);
  @override
  Future<List<String>> names() => delegate.names();
  @override
  Future<void> remove(String name) async {
    if (failRemove) throw const FileSystemException('Synthetic delete failure');
    await delegate.remove(name);
  }
}
