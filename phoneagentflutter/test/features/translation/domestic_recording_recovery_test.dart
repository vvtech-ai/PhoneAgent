import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/translation/data/recording/domestic_recording_recovery.dart';
import 'package:phone_agent/features/translation/data/recording/pcm_recording_journal.dart';
import 'package:phone_agent/features/translation/data/recording/private_domestic_recording_files.dart';
import 'package:phone_agent/features/translation/domain/recording/domestic_recording_encoder.dart';
import 'package:phone_agent/features/translation/domain/recording/pcm_timeline.dart';
import 'package:phone_agent/features/translation/domain/translation_archive.dart';

class Encoder implements DomesticRecordingEncoder {
  int calls = 0;
  @override
  Future<void> encode({
    required String pcmPath,
    required String m4aPath,
  }) async {
    calls++;
    await File(m4aPath).writeAsBytes([1, 2, 3]);
  }
}

void main() {
  late Directory root;
  late PrivateDomesticRecordingFiles files;
  var current = true;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('recording-recovery');
    current = true;
    files = PrivateDomesticRecordingFiles(
      environment: 'test',
      apiBase: 'https://example.invalid',
      accountId: 'synthetic',
      root: () async => root,
      isCurrent: () => current,
    );
  });
  tearDown(() async => root.delete(recursive: true));
  TranslationArchiveEntry entry() => TranslationArchiveEntry(
    accountId: 'synthetic',
    clientCallId: 'synthetic-call',
    targetName: '合成',
    phone: '13800138000',
    myLanguage: 'zh',
    peerLanguage: 'en',
    route: TranslationArchiveRoute.domesticSip,
    connectedAt: 1000,
    endedAt: 1020,
    stage: TranslationArchiveStage.ready,
    recordingPending: true,
  );
  test(
    'startup completes owned capture and reuses receipt without reopening a phone',
    () async {
      final capture = await files.create('synthetic-call', 100);
      capture.offer(
        RecordedPcmChunk(
          TranslationRecordingTrack.localCaller,
          100,
          Uint8List(640),
        ),
      );
      await capture.finish();
      final encoder = Encoder(),
          recovery = DomesticRecordingRecovery(files, Encoder());
      final ready = await recovery.prepare(entry());
      expect(ready.recordingPending, false);
      expect(ready.recording!.durationMillis, 20);
      final again = await DomesticRecordingRecovery(
        files,
        encoder,
      ).prepare(entry());
      expect(again.recording!.checksumSha256, ready.recording!.checksumSha256);
      expect(encoder.calls, 0);
    },
  );
  test(
    'incomplete capture is unavailable and retained, while account mismatch refuses',
    () async {
      final capture = await files.create('synthetic-call', 0);
      capture.offer(
        RecordedPcmChunk(
          TranslationRecordingTrack.localCaller,
          0,
          Uint8List(640),
        ),
      );
      final recovery = DomesticRecordingRecovery(files, Encoder());
      final ready = await recovery.prepare(entry());
      expect(ready.recordingPending, false);
      expect(ready.recording, isNull);
      expect(await capture.file.exists(), true);
      await capture.finish();
      current = false;
      await expectLater(recovery.prepare(entry()), throwsStateError);
    },
  );
}
