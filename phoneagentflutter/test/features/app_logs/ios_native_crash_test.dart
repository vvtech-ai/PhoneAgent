import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/native_crash_host.dart';
import 'package:phone_agent/core/diagnostics/diagnostic_event.dart';
import 'package:phone_agent/core/diagnostics/diagnostic_journal.dart';
import 'package:phone_agent/core/diagnostics/native_crash_importer.dart';
import 'package:phone_agent/features/app_logs/data/zip_log_repository.dart';
import 'native_crash_importer_test.dart';

Map<String, Object> iosRow() => {
  ...row(scopeA),
  'platform': 'ios',
  'iosCrash': {
    'schema': 1,
    'signal': 'SIGABRT',
    'exception': 'NSInvalidArgumentException',
    'appVersion': '1.0.52',
    'appBuild': '45',
    'osVersion': '18.6',
    'architecture': 'arm64',
    'deviceModel': 'iPhone15,2',
    'frames': [
      {
        'thread': 3,
        'crashed': true,
        'image': 'Runner',
        'uuid': 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
        'base': '100000000',
        'pc': '100001234',
        'offset': '1234',
      },
    ],
    'reason': 'private-token',
    'path': '/private/user/data',
  },
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('iOS provider is enabled and desktop remains disabled', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(container.read(nativeCrashPortProvider), isNotNull);
    container.invalidate(nativeCrashPortProvider);
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    expect(container.read(nativeCrashPortProvider), isNull);
  });
  test(
    'iOS summary survives persistence and real ZIP without raw error data',
    () async {
      final event = NativeCrashSummary.fromMap(iosRow(), scopeA).event;
      expect(event.operation.name, 'iosNativeCrash');
      final decoded = DiagnosticEvent.fromJson(event.toJson());
      expect(decoded.toJson()['iosCrash'], isNotNull);
      final store = MemoryCrashJournalStore();
      final journal = DiagnosticJournal(store);
      final port = FakeCrashPort()
        ..rows[scopeA] = [NativeCrashSummary.fromMap(iosRow(), scopeA)];
      final importer = NativeCrashImporter(port);
      expect(await importer.activate(scopeA, journal), isTrue);
      final restored = DiagnosticJournal(store);
      final bundle = await ZipLogRepository(
        restored,
        uploadBundle: (_) async {},
      ).prepare();
      final archive = ZipDecoder().decodeBytes(bundle.bytes, verify: true);
      final text = utf8.decode(archive.files.single.content as List<int>);
      expect(text, contains('iosNativeCrash'));
      expect(text, contains('aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee'));
      expect(text, contains('100001234'));
      expect(text, isNot(contains('private')));
      expect(port.acks.single.$1, scopeA);
      importer.close();
      journal.close();
      restored.close();
    },
  );
  test(
    'iOS rejects malformed frames and unknown platform without acknowledging',
    () {
      for (final update in [
        {'platform': 'unknown'},
        {'iosCrash': <String, Object>{}},
        {'scope': scopeB},
      ]) {
        expect(
          () => NativeCrashSummary.fromMap({...iosRow(), ...update}, scopeA),
          throwsFormatException,
        );
      }
    },
  );
  test(
    'upload prepare imports pending without rebinding another logged-in owner',
    () async {
      final port = FakeCrashPort()
        ..rows[scopeA] = [NativeCrashSummary.fromMap(iosRow(), scopeA)];
      final importer = NativeCrashImporter(port);
      final journal = DiagnosticJournal(MemoryCrashJournalStore());
      await port.bind(scopeB);
      final repository = ZipLogRepository(
        journal,
        uploadBundle: (_) async {},
        beforePrepare: () async {
          await importer.importPending(scopeA, journal);
        },
      );
      final bundle = await repository.prepare();
      expect(bundle.count, 1);
      expect(port.bindings, [scopeB]);
      final second = await repository.prepare();
      expect(second.count, 1);
      importer.close();
      journal.close();
    },
  );
  test(
    'failed import keeps pending evidence but does not block old logs',
    () async {
      final port = FakeCrashPort()
        ..rows[scopeA] = [NativeCrashSummary.fromMap(iosRow(), scopeA)]
        ..failAck = true;
      final importer = NativeCrashImporter(port);
      final journal = DiagnosticJournal(MemoryCrashJournalStore());
      final repository = ZipLogRepository(
        journal,
        uploadBundle: (_) async {},
        beforePrepare: () async {
          await importer.importPending(scopeA, journal);
        },
      );
      expect((await repository.prepare()).count, 1);
      expect(port.rows[scopeA], hasLength(1));
      port.failAck = false;
      expect((await repository.prepare()).count, 1);
      expect(port.rows[scopeA], isEmpty);
      importer.close();
      journal.close();
    },
  );
}
