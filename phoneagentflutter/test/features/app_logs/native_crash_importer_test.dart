import 'dart:async';
import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/diagnostics/diagnostic_event.dart';
import 'package:phone_agent/core/diagnostics/diagnostic_journal.dart';
import 'package:phone_agent/core/diagnostics/native_crash_importer.dart';
import 'package:phone_agent/features/app_logs/data/device_native_crash_port.dart';
import 'package:phone_agent/features/app_logs/data/zip_log_repository.dart';

final scopeA = nativeCrashScope('dev|https://example.test/|account-a');
final scopeB = nativeCrashScope('dev|https://example.test/|account-b');
const id = '11111111-1111-4111-8111-111111111111';
Map<String, Object> row(String scope) => {
  'scope': scope,
  'id': id,
  'time': 1789928326219,
  'mainThread': true,
  'kind': 'state',
  'message': 'private-token',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('closed journal must not acknowledge a discarded event', () async {
    final journal = DiagnosticJournal(MemoryCrashJournalStore())..close();
    final port = FakeCrashPort()
      ..rows[scopeA] = [NativeCrashSummary.fromMap(row(scopeA), scopeA)];
    final importer = NativeCrashImporter(port);
    expect(await importer.activate(scopeA, journal), isFalse);
    expect(port.acks, isEmpty);
    importer.close();
  });

  test(
    'strict typed summary excludes arbitrary data and round-trips old/new journal',
    () {
      final event = NativeCrashSummary.fromMap(row(scopeA), scopeA).event;
      expect(event.operation, DiagnosticOperation.androidMainUnhandled);
      expect(event.failureKind, DiagnosticFailureKind.state);
      expect(event.traceId, id);
      expect(jsonEncode(event.toJson()), isNot(contains('private')));
      expect(DiagnosticEvent.fromJson(event.toJson()).traceId, id);
      for (final update in <Map<String, Object>>[
        {'scope': scopeB},
        {'id': '../bad'},
        {'time': -1},
        {'time': 1.5},
        {'kind': 'private'},
        {'mainThread': 'true'},
      ]) {
        expect(
          () => NativeCrashSummary.fromMap({...row(scopeA), ...update}, scopeA),
          throwsFormatException,
        );
      }
      final background = NativeCrashSummary.fromMap({
        ...row(scopeA),
        'mainThread': false,
      }, scopeA);
      expect(
        background.event.operation,
        DiagnosticOperation.androidBackgroundUnhandled,
      );
      final old = DiagnosticEvent(
        operation: DiagnosticOperation.accountRequest,
        result: DiagnosticResult.succeeded,
      );
      expect(DiagnosticEvent.fromJson(old.toJson()).operation, old.operation);
      expect(scopeA, matches(RegExp('^[0-9a-f]{64}\$')));
      expect(scopeA, isNot(scopeB));
    },
  );

  test(
    'commit then exact ack; reload and actual ZIP contain safe crash event',
    () async {
      final store = MemoryCrashJournalStore();
      final journal = DiagnosticJournal(store);
      final port = FakeCrashPort()
        ..rows[scopeA] = [NativeCrashSummary.fromMap(row(scopeA), scopeA)];
      final importer = NativeCrashImporter(port);
      port.onAck = () {
        expect(store.value, contains('androidMainUnhandled'));
      };
      expect(await importer.activate(scopeA, journal), isTrue);
      expect(port.acks.single.$1, scopeA);
      expect(port.acks.single.$2, [id]);
      final reloaded = DiagnosticJournal(store);
      final bundle = await ZipLogRepository(
        reloaded,
        uploadBundle: (_) async {
          fail('must not upload');
        },
      ).prepare();
      final zip = ZipDecoder().decodeBytes(bundle.bytes, verify: true);
      final text = utf8.decode(zip.files.single.content as List<int>);
      expect(text, contains(id));
      expect(text, isNot(contains('private')));
      importer.close();
      journal.close();
      reloaded.close();
    },
  );

  test(
    'flush failure and ack failure retry without same-process duplicates',
    () async {
      final store = MemoryCrashJournalStore()..failWrite = true;
      final journal = DiagnosticJournal(store);
      final port = FakeCrashPort()
        ..rows[scopeA] = [NativeCrashSummary.fromMap(row(scopeA), scopeA)];
      final importer = NativeCrashImporter(port);
      expect(await importer.activate(scopeA, journal), isFalse);
      expect(port.acks, isEmpty);
      store.failWrite = false;
      port.failAck = true;
      expect(await importer.activate(scopeA, journal), isFalse);
      port.failAck = false;
      expect(await importer.activate(scopeA, journal), isTrue);
      expect((await journal.snapshot()).events.length, 1);
      expect(await importer.activate(scopeA, journal), isTrue);
      expect((await journal.snapshot()).events.length, 1);
      importer.close();
      journal.close();
    },
  );

  test(
    'late old read keeps old journal; concurrent same-scope imports serialized',
    () async {
      final a = DiagnosticJournal(MemoryCrashJournalStore());
      final b = DiagnosticJournal(MemoryCrashJournalStore());
      final gate = Completer<List<NativeCrashSummary>>();
      final port = FakeCrashPort()..readGate = gate;
      final importer = NativeCrashImporter(port);
      final first = importer.activate(scopeA, a);
      await Future<void>.delayed(Duration.zero);
      final retry = importer.activate(scopeA, a);
      final other = importer.activate(scopeB, b);
      await other;
      gate.complete([NativeCrashSummary.fromMap(row(scopeA), scopeA)]);
      expect(await first, isTrue);
      expect(await retry, isTrue);
      expect((await a.snapshot()).events.length, 1);
      expect((await b.snapshot()).events, isEmpty);
      expect(port.bindings.last, scopeB);
      expect(port.acks.every((ack) => ack.$1 == scopeA), isTrue);
      importer.close();
      a.close();
      b.close();
    },
  );

  test(
    'dispose during read neither records nor acknowledges; bind errors isolated',
    () async {
      final gate = Completer<List<NativeCrashSummary>>();
      final port = FakeCrashPort()..readGate = gate;
      final importer = NativeCrashImporter(port);
      final journal = DiagnosticJournal(MemoryCrashJournalStore());
      final pending = importer.activate(scopeA, journal);
      await Future<void>.delayed(Duration.zero);
      importer.close();
      gate.complete([NativeCrashSummary.fromMap(row(scopeA), scopeA)]);
      expect(await pending, isFalse);
      expect(port.acks, isEmpty);
      expect((await journal.snapshot()).events, isEmpty);
      expect(port.bindings.last, isNull);
      final failing = NativeCrashImporter(FakeCrashPort()..failBind = true);
      expect(await failing.activate(scopeA, journal), isFalse);
      failing.close();
      journal.close();
    },
  );

  test(
    'device protocol rejects wrong scope/oversized/invalid rows and acknowledges exact ids',
    () async {
      const channel = MethodChannel('phone_agent/native_crash');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      Object? response = [row(scopeA)];
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return call.method == 'read' ? response : null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      const port = DeviceNativeCrashPort();
      await port.bind(scopeA);
      expect((await port.read(scopeA)).single.id, id);
      await port.acknowledge(scopeA, [id]);
      expect(calls.last.arguments, {
        'scope': scopeA,
        'ids': [id],
      });
      for (final invalid in [
        null,
        {},
        [row(scopeB)],
        ['bad'],
        List.filled(33, row(scopeA)),
      ]) {
        response = invalid;
        await expectLater(port.read(scopeA), throwsFormatException);
      }
    },
  );
}

class MemoryCrashJournalStore implements DiagnosticStore {
  String? value;
  bool failWrite = false;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String text) async {
    if (failWrite) throw StateError('private disk error');
    value = text;
  }
}

class FakeCrashPort implements NativeCrashPort {
  final rows = <String, List<NativeCrashSummary>>{};
  final bindings = <String?>[];
  final acks = <(String, List<String>)>[];
  bool failAck = false, failBind = false;
  void Function()? onAck;
  Completer<List<NativeCrashSummary>>? readGate;
  @override
  Future<void> bind(String? scope) async {
    bindings.add(scope);
    if (failBind) throw StateError('private bind error');
  }

  @override
  Future<List<NativeCrashSummary>> read(String scope) async {
    if (scope == scopeA && readGate != null) {
      final gate = readGate!;
      readGate = null;
      return gate.future;
    }
    return rows[scope] ?? [];
  }

  @override
  Future<void> acknowledge(String scope, List<String> ids) async {
    onAck?.call();
    if (failAck) throw StateError('private cleanup error');
    acks.add((scope, ids));
    rows[scope]?.removeWhere((r) => ids.contains(r.id));
  }
}
