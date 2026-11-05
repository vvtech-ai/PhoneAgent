import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/network/account_session.dart';
import 'package:phone_agent/features/translation/domain/translation_archive.dart';
import 'package:phone_agent/features/translation/data/translation_archive_codec.dart';
import 'package:phone_agent/features/translation/data/secure_translation_archive_store.dart';
import 'package:phone_agent/features/translation/data/api_translation_archive_gateway.dart';
import '../../support/synthetic_account_api.dart';

TranslationArchiveEntry entry({String account = 'a', String id = 'client-1'}) =>
    TranslationArchiveEntry(
      accountId: account,
      clientCallId: id,
      targetName: '合成',
      phone: '+12025550123',
      myLanguage: 'zh',
      peerLanguage: 'en',
      locator: const TranslationArchiveLocator(
        'JP',
        'remote-1',
        'synthetic-grant',
      ),
      connectedAt: 1000,
      endedAt: 1500,
      stage: TranslationArchiveStage.ready,
    );

void main() {
  test(
    'codec round trip excludes media credentials and rejects foreign/corrupt schema',
    () {
      final raw = TranslationArchiveCodec.encode('scope', 'a', [entry()]);
      expect(
        TranslationArchiveCodec.decode('scope', 'a', raw).single.locator!.grant,
        'synthetic-grant',
      );
      expect(raw.contains('liveKit'), false);
      expect(raw.contains('token'), false);
      expect(
        () => TranslationArchiveCodec.decode('scope', 'b', raw),
        throwsFormatException,
      );
      expect(
        () => TranslationArchiveCodec.decode('other', 'a', raw),
        throwsFormatException,
      );
      expect(
        () => TranslationArchiveCodec.decode(
          'scope',
          'a',
          raw.replaceFirst('"version":1', '"version":2'),
        ),
        throwsFormatException,
      );
      expect(
        () => TranslationArchiveCodec.encode('scope', 'a', [entry(), entry()]),
        throwsFormatException,
      );
      expect(
        () =>
            TranslationArchiveCodec.encode('scope', 'a', [entry(id: '../bad')]),
        throwsFormatException,
      );
    },
  );
  test(
    'secure journal restores same scope and keeps account/environment separate',
    () async {
      final disk = <String, String>{};
      SecureTranslationArchiveStore make({
        String environment = 'dev',
        String account = 'a',
      }) => SecureTranslationArchiveStore(
        environment: environment,
        apiBase: 'https://example.test',
        accountId: account,
        isCurrent: () => true,
        read: (key) async => disk[key],
        write: (key, value) async {
          disk[key] = value;
        },
      );
      final first = make();
      await first.save([entry()]);
      expect((await make().load()).single.clientCallId, 'client-1');
      expect(await make(account: 'b').load(), isEmpty);
      expect(await make(environment: 'prod').load(), isEmpty);
      expect(first.key.contains('example'), false);
      await first.save([]);
      expect(await make().load(), isEmpty);
    },
  );
  test(
    'unknown journal cannot be overwritten and account change blocks late write',
    () async {
      var raw = '{"version":999}', writes = 0, current = true;
      final store = SecureTranslationArchiveStore(
        environment: 'dev',
        apiBase: 'https://example.test',
        accountId: 'a',
        isCurrent: () => current,
        read: (_) async => raw,
        write: (_, value) async {
          writes++;
          raw = value;
        },
      );
      await expectLater(store.save([]), throwsFormatException);
      expect(writes, 0);
      final pending = Completer<String?>();
      final lateStore = SecureTranslationArchiveStore(
        environment: 'dev',
        apiBase: 'https://other.test',
        accountId: 'a',
        isCurrent: () => current,
        read: (_) => pending.future,
        write: (_, __) async {
          writes++;
        },
      );
      final write = lateStore.save([entry()]);
      final assertion = expectLater(write, throwsStateError);
      await Future<void>.delayed(Duration.zero);
      current = false;
      pending.complete(null);
      await assertion;
      expect(writes, 0);
    },
  );
  test(
    'API uses account envelope and idempotent WORLD_CALL PUT without domestic billing',
    () async {
      final http = SyntheticAccountApi();
      addTearDown(http.api.close);
      http.data = {'callId': 'server-id', 'created': true};
      final gateway = ApiTranslationArchiveGateway(http.api, 'a');
      expect(await gateway.archive(entry()), 'server-id');
      http.data = {'callId': 'server-id', 'created': false};
      expect(await gateway.archive(entry()), 'server-id');
      final request = http.requests.singleWhere(
        (e) => identical(e, http.requests.first),
      );
      expect(request.method, 'PUT');
      expect(request.uri.path, '/api/realtime-translation-calls/client-1');
      expect(http.requests.last.uri, request.uri);
      expect(request.headers['X-Account-Id'], 'a');
      expect(request.headers['Authorization'], 'Bearer synthetic');
      final data = request.data as Map;
      expect(data['route'], 'WORLD_CALL');
      expect(data['externalClusterId'], 'JP');
      expect(data['externalCallSessionId'], 'remote-1');
      expect(data['recordingAccessGrant'], 'synthetic-grant');
      expect(
        DateTime.parse(data['endedAt'] as String).millisecondsSinceEpoch,
        1500,
      );
      expect(jsonEncode(data).contains('billingSession'), false);
    },
  );
  test(
    'API invalid response / rejection is not completion; no automatic retry',
    () async {
      final http = SyntheticAccountApi();
      addTearDown(http.api.close);
      final gateway = ApiTranslationArchiveGateway(http.api, 'a');
      http.data = {'callId': '', 'created': true};
      await expectLater(
        gateway.archive(entry()),
        throwsA(ApiFailure.invalidResponse),
      );
      expect(http.requests.length, 1);
      http.status = 503;
      await expectLater(gateway.archive(entry()), throwsA(ApiFailure.rejected));
      expect(http.requests.length, 2);
      await expectLater(
        gateway.archive(entry(account: 'b')),
        throwsA(ApiFailure.invalidResponse),
      );
      expect(http.requests.length, 2);
    },
  );
}
