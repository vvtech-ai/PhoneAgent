import 'dart:convert';
import 'package:phone_agent/features/translation/domain/recording/domestic_recording_attachment.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/translation/data/api_translation_archive_gateway.dart';
import 'package:phone_agent/features/translation/data/translation_archive_codec.dart';
import 'package:phone_agent/features/translation/domain/translation_archive.dart';
import '../../support/synthetic_account_api.dart';

TranslationArchiveEntry entry({TranslationArchiveLocator? locator}) =>
    TranslationArchiveEntry(
      accountId: 'a',
      clientCallId: 'synthetic-call',
      targetName: '合成',
      phone: '13800138000',
      myLanguage: 'zh',
      peerLanguage: 'en',
      route: TranslationArchiveRoute.domesticSip,
      locator: locator,
      connectedAt: 1000,
      endedAt: 1500,
      stage: TranslationArchiveStage.ready,
    );

class UploadProbe implements DomesticRecordingUploader {
  bool fail = true;
  final calls = <String>[];
  @override
  Future<void> upload({
    required String serverCallId,
    required String clientCallId,
    required DomesticRecordingAttachment recording,
  }) async {
    calls.add('$serverCallId/$clientCallId');
    if (fail) throw const FormatException('synthetic upload failure');
  }
}

void main() {
  test(
    'late recording completion may update sealed journal without changing transcripts or time',
    () async {
      final pending = entry().copy(recordingPending: true);
      final attachment = DomesticRecordingAttachment(
        durationMillis: 500,
        checksumSha256: List.filled(64, 'a').join(),
      );
      final ready = pending.merge(entry().copy(recording: attachment));
      expect(ready.recordingPending, false);
      expect(ready.recording, attachment);
      expect(ready.endedAt, pending.endedAt);
      final http = SyntheticAccountApi();
      addTearDown(http.api.close);
      await expectLater(
        ApiTranslationArchiveGateway(http.api, 'a').archive(pending),
        throwsA(anything),
      );
      expect(http.requests, isEmpty);
      final stored = TranslationArchiveCodec.decode(
        'scope',
        'a',
        TranslationArchiveCodec.encode('scope', 'a', [pending]),
      ).single.recover();
      expect(stored.recordingPending, true);
    },
  );
  test(
    'recording metadata survives journal and upload failure keeps archive incomplete',
    () async {
      final attachment = DomesticRecordingAttachment(
        durationMillis: 500,
        checksumSha256: List.filled(64, 'a').join(),
      );
      final value = entry().copy(recording: attachment);
      final recovered = TranslationArchiveCodec.decode(
        'scope',
        'a',
        TranslationArchiveCodec.encode('scope', 'a', [value]),
      ).single.recover();
      expect(recovered.recording!.checksumSha256, attachment.checksumSha256);
      final http = SyntheticAccountApi();
      addTearDown(http.api.close);
      http.data = {'callId': 'synthetic-server', 'created': false};
      final probe = UploadProbe();
      final links = <String>[];
      final gateway = ApiTranslationArchiveGateway(
        http.api,
        'a',
        recordingUploader: probe,
        onDomesticArchived: (server, client) async =>
            links.add("$server/$client"),
      );
      await expectLater(gateway.archive(recovered), throwsFormatException);
      expect(links, ["synthetic-server/synthetic-call"]);
      probe.fail = false;
      expect(await gateway.archive(recovered), 'synthetic-server');
      expect(probe.calls, [
        'synthetic-server/synthetic-call',
        'synthetic-server/synthetic-call',
      ]);
      expect(http.requests.length, 2);
    },
  );
  test('recording requires domestic route and exact physical duration', () {
    final value = entry().copy(
      recording: DomesticRecordingAttachment(
        durationMillis: 501,
        checksumSha256: List.filled(64, 'a').join(),
      ),
    );
    expect(
      () => TranslationArchiveCodec.encode('scope', 'a', [value]),
      throwsFormatException,
    );
  });
  test(
    'domestic archive uses native shared route and never sends world recording grant',
    () async {
      final http = SyntheticAccountApi();
      addTearDown(http.api.close);
      http.data = {'callId': 'synthetic-archive', 'created': true};
      final gateway = ApiTranslationArchiveGateway(http.api, 'a');
      expect(await gateway.archive(entry()), 'synthetic-archive');
      final request = http.requests.single;
      expect(request.method, 'PUT');
      final body = request.data as Map;
      expect(body['route'], 'DOMESTIC_ANDROID');
      expect(body.containsKey('recordingAccessGrant'), false);
      expect(body.containsKey('externalCallSessionId'), false);
      expect(body['phoneNumber'], '13800138000');
      expect(request.headers['X-Account-Id'], 'a');
      await expectLater(
        gateway.archive(
          entry(
            locator: const TranslationArchiveLocator(
              'JP',
              'synthetic',
              'synthetic-grant',
            ),
          ),
        ),
        throwsA(anything),
      );
      expect(http.requests.length, 1);
    },
  );
  test(
    'route survives copy/recover and scoped journal while old missing route stays world',
    () {
      final current = entry();
      expect(current.recover().route, TranslationArchiveRoute.domesticSip);
      final raw = TranslationArchiveCodec.encode('scope', 'a', [current]);
      expect(
        TranslationArchiveCodec.decode('scope', 'a', raw).single.route,
        TranslationArchiveRoute.domesticSip,
      );
      final legacy = jsonDecode(raw) as Map<String, dynamic>;
      (legacy['entries'] as List).single.remove('route');
      expect(
        TranslationArchiveCodec.decode(
          'scope',
          'a',
          jsonEncode(legacy),
        ).single.route,
        TranslationArchiveRoute.worldCall,
      );
      (legacy['entries'] as List).single['route'] = 'future-route';
      expect(
        () => TranslationArchiveCodec.decode('scope', 'a', jsonEncode(legacy)),
        throwsFormatException,
      );
    },
  );
}
