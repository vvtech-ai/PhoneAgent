import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/translation/data/api_translation_archive_gateway.dart';
import 'package:phone_agent/features/translation/data/preview_translation_archive.dart';
import 'package:phone_agent/features/translation/domain/translation_archive.dart';
import 'package:phone_agent/features/translation/domain/recording/domestic_recording_attachment.dart';
import 'package:phone_agent/features/translation/presentation/controller/translation_archive_controller.dart';
import '../../support/synthetic_account_api.dart';

class _Uploader implements DomesticRecordingUploader {
  int attempts = 0;
  bool fail = true;
  @override
  Future<void> upload({
    required String serverCallId,
    required String clientCallId,
    required DomesticRecordingAttachment recording,
  }) async {
    attempts++;
    expect(serverCallId, 'server-synthetic');
    expect(clientCallId, 'client-synthetic');
    if (fail) throw StateError('synthetic upload failure');
  }
}

TranslationArchiveEntry _entry({bool missing = false}) =>
    TranslationArchiveEntry(
      accountId: 'synthetic',
      clientCallId: 'client-synthetic',
      targetName: '合成',
      phone: '10086',
      myLanguage: 'zh',
      peerLanguage: 'en',
      connectedAt: 1000,
      endedAt: 2000,
      stage: TranslationArchiveStage.ready,
      route: TranslationArchiveRoute.domesticSip,
      recording: missing
          ? null
          : DomesticRecordingAttachment(
              durationMillis: 1000,
              checksumSha256: 'a' * 64,
            ),
    );
void main() {
  test(
    'production phased gateway retries upload without repeating PUT after restart',
    () async {
      final api = SyntheticAccountApi()
        ..data = {'callId': 'server-synthetic', 'created': true};
      addTearDown(api.api.close);
      final store = PreviewTranslationArchive();
      await store.save([_entry()]);
      final uploader = _Uploader();
      var binds = 0;
      final gateway = ApiTranslationArchiveGateway(
        api.api,
        'synthetic',
        recordingUploader: uploader,
        onDomesticArchived: (server, client) async {
          expect((await store.load()).single.serverCallId, server);
          binds++;
        },
      );
      TranslationArchiveController owner() => TranslationArchiveController(
        accountId: 'synthetic',
        store: store,
        gateway: gateway,
        isCurrent: () => true,
      );
      final first = owner();
      await first.recover();
      expect(api.requests, hasLength(1));
      expect(api.requests.single.method, 'PUT');
      expect(
        (await store.load()).single.stage,
        TranslationArchiveStage.recordingUpload,
      );
      first.dispose();
      uploader.fail = false;
      final second = owner();
      await second.recover();
      expect(api.requests, hasLength(1));
      expect(uploader.attempts, 2);
      expect(binds, 2);
      expect(await store.load(), isEmpty);
      second.dispose();
    },
  );
  test(
    'native no-recording fallback creates record and binds without upload',
    () async {
      final api = SyntheticAccountApi()
        ..data = {'callId': 'server-synthetic', 'created': true};
      addTearDown(api.api.close);
      var binds = 0;
      final gateway = ApiTranslationArchiveGateway(
        api.api,
        'synthetic',
        onDomesticArchived: (_, __) async {
          binds++;
        },
      );
      expect(await gateway.archive(_entry(missing: true)), 'server-synthetic');
      expect(api.requests, hasLength(1));
      expect(binds, 1);
    },
  );
}
