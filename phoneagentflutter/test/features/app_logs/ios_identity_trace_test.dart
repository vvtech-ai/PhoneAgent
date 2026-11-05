import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/diagnostics/diagnostic_event.dart';
import 'package:phone_agent/core/diagnostics/diagnostic_journal.dart';
import 'package:phone_agent/core/diagnostics/native_crash_importer.dart';
import 'package:phone_agent/features/app_logs/data/zip_log_repository.dart';
import 'ios_native_crash_test.dart';
import 'native_crash_importer_test.dart';

Map<String, Object> traceRow() => {
  ...row(scopeA),
  'platform': 'ios',
  'kind': 'identityTrace',
  'iosTrace': {
    'schema': 1,
    'runId': 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
    'appVersion': '1.0.52',
    'appBuild': '45',
    'runnerUUID': '11111111-2222-3333-4444-555555555555',
    'configuredSdk': '2.3.50',
    'osVersion': '26.6.1',
    'deviceModel': 'iPhone15,4',
    'dropped': 2,
    'writeFailures': 1,
    'unbound': 3,
    'events': [
      for (final entry in ['prepare.enter', 'sdk.callback', 'reset.exit'])
        {
          'seq':
              ['prepare.enter', 'sdk.callback', 'reset.exit'].indexOf(entry) +
              1,
          'time': 1792397013081,
          'monotonicUs': 123456,
          'thread': '123',
          'main': entry != 'sdk.callback',
          'event': entry,
          'session': '11111111-1111-4111-8111-111111111111',
          'actor': '22222222-2222-4222-8222-222222222222',
          'flags': 15,
          'code': 1000,
          'category': 'AVAudioSessionCategoryPlayAndRecord',
          'mode': 'AVAudioSessionModeDefault',
          'sampleRate': 48000,
          'inputs': ['MicrophoneBuiltIn'],
          'outputs': ['Speaker'],
          'token': 'private-secret',
          'recording': 'private-audio',
        },
    ],
    'certifyId': 'private-certify',
  },
};

void main() {
  for (final level in [DiagnosticLogLevel.warn, DiagnosticLogLevel.error]) {
    test(
      'retained native evidence survives $level verbosity before ack',
      () async {
        final port = FakeCrashPort()
          ..rows[scopeA] = [NativeCrashSummary.fromMap(traceRow(), scopeA)];
        final store = MemoryCrashJournalStore();
        final journal = DiagnosticJournal(store, minimumLevel: level);
        final importer = NativeCrashImporter(port);
        expect(await importer.activate(scopeA, journal), isTrue);
        final restored = DiagnosticJournal(store, minimumLevel: level);
        expect((await restored.snapshot()).events, hasLength(1));
        expect(port.acks, hasLength(1));
        importer.close();
        journal.close();
        restored.close();
      },
    );
  }
  test(
    'trace survives failed durable write and failed native acknowledgement',
    () async {
      final port = FakeCrashPort()
        ..rows[scopeA] = [NativeCrashSummary.fromMap(traceRow(), scopeA)];
      final store = MemoryCrashJournalStore()..failWrite = true;
      final journal = DiagnosticJournal(store);
      final importer = NativeCrashImporter(port);
      expect(await importer.activate(scopeA, journal), isFalse);
      expect(port.acks, isEmpty);
      expect(port.rows[scopeA], hasLength(1));
      store.failWrite = false;
      port.failAck = true;
      expect(await importer.importPending(scopeA, journal), isFalse);
      final restored = DiagnosticJournal(store);
      expect((await restored.snapshot()).events, hasLength(1));
      port.failAck = false;
      expect(await importer.importPending(scopeA, journal), isTrue);
      expect(port.rows[scopeA], isEmpty);
      expect((await journal.snapshot()).events, hasLength(1));
      importer.close();
      journal.close();
      restored.close();
    },
  );

  test(
    'durable native lifecycle survives import and ZIP without being a crash',
    () async {
      final port = FakeCrashPort()
        ..rows[scopeA] = [NativeCrashSummary.fromMap(traceRow(), scopeA)];
      final store = MemoryCrashJournalStore();
      final journal = DiagnosticJournal(store);
      final importer = NativeCrashImporter(port);
      expect(await importer.activate(scopeA, journal), isTrue);
      final restored = DiagnosticJournal(store);
      final bundle = await ZipLogRepository(
        restored,
        uploadBundle: (_) async {},
      ).prepare();
      final text = utf8.decode(
        ZipDecoder().decodeBytes(bundle.bytes).files.single.content
            as List<int>,
      );
      expect(text, contains('iosIdentityTrace'));
      expect(text, isNot(contains('iosNativeCrash')));
      expect(text, isNot(contains('private')));
      final data = jsonDecode(text) as Map;
      final events = (data['iosTrace'] as Map)['events'] as List;
      expect(events.map((e) => e['event']), [
        'prepare.enter',
        'sdk.callback',
        'reset.exit',
      ]);
      expect(events[1]['main'], isFalse);
      expect(data['iosTrace']['dropped'], 2);
      expect(
        data['iosTrace']['runnerUUID'],
        '11111111-2222-3333-4444-555555555555',
      );
      importer.close();
      journal.close();
      restored.close();
    },
  );

  test(
    'native lifecycle rejects oversized input and preserves account isolation',
    () {
      final input = traceRow();
      expect(
        () => NativeCrashSummary.fromMap(input, scopeB),
        throwsFormatException,
      );
      final details = input['iosTrace'] as Map<String, Object>;
      details['events'] = List.filled(129, (details['events'] as List).first);
      expect(
        () => NativeCrashSummary.fromMap(input, scopeA),
        throwsFormatException,
      );
    },
  );

  test(
    'expanded crash evidence retains signal address and secondary threads',
    () {
      final input = iosRow();
      final details = input['iosCrash'] as Map<String, Object>;
      details['schema'] = 2;
      details['runId'] = 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee';
      details['signalCode'] = 'SEGV_MAPERR';
      details['faultAddress'] = '400000000000bad0';
      details['threadCount'] = 24;
      details['frameCount'] = 300;
      details['frames'] = List.generate(
        300,
        (i) => {
          ...(details['frames'] as List).first as Map,
          'thread': i ~/ 16,
          'crashed': i < 16,
        },
      );
      final encoded = NativeCrashSummary.fromMap(input, scopeA).event.toJson();
      final recovered =
          DiagnosticEvent.fromJson(encoded).toJson()['iosCrash'] as Map;
      expect(recovered['faultAddress'], '400000000000bad0');
      expect(recovered['signalCode'], 'SEGV_MAPERR');
      expect(recovered['frames'], hasLength(300));
      expect(recovered['runId'], details['runId']);
      expect(recovered.containsKey('reason'), isFalse);
    },
  );
}
