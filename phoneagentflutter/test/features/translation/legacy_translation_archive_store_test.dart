import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/translation/data/legacy_translation_archive_codec.dart';
import 'package:phone_agent/features/translation/data/secure_translation_archive_store.dart';
import 'package:phone_agent/features/translation/data/api_translation_archive_gateway.dart';
import 'package:phone_agent/features/translation/domain/translation_archive.dart';
import 'package:phone_agent/features/translation/presentation/controller/translation_archive_controller.dart';
import '../../support/legacy_translation_fixture.dart';
import '../../support/synthetic_account_api.dart';

void main() {
  late Map<String, String> disk;
  var reads = 0,
      failRead = false,
      failWrite = false,
      failSource = false,
      current = true;
  List<TranslationArchiveEntry>? source;
  Future<List<TranslationArchiveEntry>?> Function()? delayedSource;
  List<TranslationArchiveEntry> old({String stage = 'READY_TO_ARCHIVE'}) =>
      LegacyTranslationArchiveCodec.decode(
        'a',
        jsonEncode([legacyTranslation(stage: stage)]),
      );
  SecureTranslationArchiveStore make() => SecureTranslationArchiveStore(
    environment: 'prod',
    apiBase: 'https://example.test/',
    accountId: 'a',
    isCurrent: () => current,
    read: (key) async {
      if (failRead) throw StateError('synthetic read');
      return disk[key];
    },
    write: (key, value) async {
      if (failWrite) throw StateError('synthetic write');
      disk[key] = value;
    },
    legacyRead: () async {
      reads++;
      if (failSource) throw StateError('synthetic source');
      return delayedSource == null ? source : delayedSource!();
    },
  );
  setUp(() {
    disk = {};
    reads = 0;
    failRead = failWrite = failSource = false;
    current = true;
    source = old();
    delayedSource = null;
  });

  test(
    'successful first import is persisted once across instances and empty tombstone',
    () async {
      expect((await make().load()).single.clientCallId, 'legacy-call');
      expect(disk, hasLength(1));
      expect((await make().load()).single.locator!.grant, 'synthetic-grant');
      await make().save([]);
      expect(await make().load(), isEmpty);
      expect(reads, 1);
    },
  );
  test(
    'new valid queue wins; corrupt/read-failed new key never falls back',
    () async {
      final existing = old().single.copy(endedAt: 1900);
      await make().save([existing]);
      final count = reads;
      expect((await make().load()).single.endedAt, 1900);
      failRead = true;
      await expectLater(make().load(), throwsStateError);
      failRead = false;
      disk[make().key] = '{bad';
      await expectLater(make().load(), throwsFormatException);
      await expectLater(make().save([]), throwsFormatException);
      expect(reads, count);
      expect(disk[make().key], '{bad');
    },
  );
  test(
    'missing source writes nothing; malformed or failed source can retry',
    () async {
      source = null;
      expect(await make().load(), isEmpty);
      expect(disk, isEmpty);
      failSource = true;
      await expectLater(make().load(), throwsStateError);
      expect(disk, isEmpty);
      failSource = false;
      source = old();
      expect((await make().load()).single.clientCallId, 'legacy-call');
    },
  );
  test(
    'write failure publishes no imported data and retry uses unchanged source',
    () async {
      failWrite = true;
      await expectLater(make().load(), throwsStateError);
      expect(disk, isEmpty);
      failWrite = false;
      expect((await make().load()).single.connectedAt, 1000);
      expect(reads, 2);
    },
  );
  test('same-key instances serialize import before newer save', () async {
    final gate = Completer<List<TranslationArchiveEntry>?>();
    final started = Completer<void>();
    delayedSource = () {
      started.complete();
      return gate.future;
    };
    final load = make().load();
    await started.future;
    final save = make().save([old().single.copy(endedAt: 2000)]);
    gate.complete(old());
    await load;
    await save;
    expect((await make().load()).single.endedAt, 2000);
    expect(reads, 1);
  });
  test(
    'owner change during old read prevents persistence and publication',
    () async {
      final gate = Completer<List<TranslationArchiveEntry>?>();
      final started = Completer<void>();
      delayedSource = () {
        started.complete();
        return gate.future;
      };
      final rejected = expectLater(make().load(), throwsStateError);
      await started.future;
      current = false;
      gate.complete(old());
      await rejected;
      expect(disk, isEmpty);
    },
  );
  test(
    'formal controller and real API adapter recover exact old ID without redial',
    () async {
      source = old(stage: 'CONNECTED');
      final api = SyntheticAccountApi()
        ..data = {'callId': 'receipt-1', 'created': false};
      addTearDown(api.api.close);
      TranslationArchiveController controller() => TranslationArchiveController(
        accountId: 'a',
        store: make(),
        gateway: ApiTranslationArchiveGateway(api.api, 'a'),
        isCurrent: () => current,
      );
      final first = controller();
      failWrite = true;
      await first.recover();
      expect(first.snapshot.failed, true);
      expect(api.requests, isEmpty);
      failWrite = false;
      api.status = 503;
      await first.retry();
      expect(first.snapshot.failed, true);
      expect((await make().load()).single.clientCallId, 'legacy-call');
      api.status = 200;
      await first.retry();
      expect(first.snapshot.completed, 1);
      expect(first.snapshot.pending, 0);
      expect(first.snapshot.failed, false);
      first.dispose();
      final restarted = controller();
      await restarted.recover();
      restarted.dispose();
      expect(api.requests, hasLength(2));
      for (final request in api.requests) {
        expect(request.method, 'PUT');
        expect(
          request.uri.toString(),
          'https://example.test/api/realtime-translation-calls/legacy-call',
        );
        final body = request.data as Map;
        expect(body['route'], 'WORLD_CALL');
        expect(body['endedAt'], '1970-01-01T00:00:01.500Z');
        expect(body['recordingAccessGrant'], 'synthetic-grant');
        expect(jsonEncode(body), isNot(contains('must-not-copy')));
      }
      expect(
        reads,
        2,
      ); // Failed initial write, then successful one-time import.
    },
  );
}
