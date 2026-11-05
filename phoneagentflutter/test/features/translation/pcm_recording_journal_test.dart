import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/translation/data/recording/pcm_recording_journal.dart';
import 'package:phone_agent/features/translation/domain/recording/pcm_timeline.dart';

void main() {
  late Directory root;
  setUp(
    () async =>
        root = await Directory.systemTemp.createTemp('pcm-journal-test'),
  );
  tearDown(() async => root.delete(recursive: true));
  Future<PcmRecordingJournal> create({String account = 'synthetic-account'}) =>
      PcmRecordingJournal.create(
        privateRoot: root,
        environment: 'test',
        apiBase: 'https://example.invalid',
        accountId: account,
        clientCallId: 'synthetic-call',
        originNanos: 100,
      );
  test(
    'bounded journal preserves tracks, time and copies submitted PCM',
    () async {
      final journal = await create();
      final source = Uint8List.fromList([1, 2, 3, 4]);
      expect(
        journal.offer(
          RecordedPcmChunk(TranslationRecordingTrack.localCaller, 120, source),
        ),
        isTrue,
      );
      source[0] = 99;
      expect(
        journal.offer(
          RecordedPcmChunk(
            TranslationRecordingTrack.peerFinalOutput,
            130,
            Uint8List.fromList([5, 6]),
          ),
        ),
        isTrue,
      );
      await journal.finish();
      final recovered = await PcmRecordingJournal.recover(journal.file);
      expect(recovered.originNanos, 100);
      await recovered.finish();
      expect(
        recovered.offer(
          RecordedPcmChunk(
            TranslationRecordingTrack.localCaller,
            0,
            Uint8List(2),
          ),
        ),
        isFalse,
      );
      final chunks = await PcmRecordingJournal.read(journal.file).toList();
      expect(chunks.map((c) => c.timestampNanos), [120, 130]);
      expect(chunks.last.track, TranslationRecordingTrack.peerFinalOutput);
      expect(chunks.first.pcm, [1, 2, 3, 4]);
      expect(journal.offer(chunks.first), isFalse);
      await journal.finish();
    },
  );
  test(
    'account isolation and existing capture cannot be overwritten',
    () async {
      final a = await create();
      final b = await create(account: 'other-synthetic-account');
      expect(a.file.path, isNot(b.file.path));
      expect(a.file.path, isNot(contains('synthetic-account')));
      await a.finish();
      await b.finish();
      await expectLater(create(), throwsStateError);
    },
  );
  test(
    'queue overflow invalidates capture instead of dropping audio silently',
    () async {
      final journal = await create();
      final chunk = RecordedPcmChunk(
        TranslationRecordingTrack.localCaller,
        100,
        Uint8List(2),
      );
      for (var i = 0; i < 256; i++) {
        expect(journal.offer(chunk), isTrue);
      }
      expect(journal.offer(chunk), isFalse);
      expect(journal.valid, isFalse);
      await expectLater(journal.finish(), throwsFormatException);
      await expectLater(
        PcmRecordingJournal.read(journal.file).toList(),
        throwsFormatException,
      );
    },
  );
  test('malformed and truncated disk input fails closed', () async {
    final journal = await create();
    journal.offer(
      RecordedPcmChunk(
        TranslationRecordingTrack.localCaller,
        120,
        Uint8List(4),
      ),
    );
    await journal.finish();
    final bytes = await journal.file.readAsBytes();
    await journal.file.writeAsBytes(bytes.sublist(0, bytes.length - 1));
    await expectLater(
      PcmRecordingJournal.read(journal.file).toList(),
      throwsFormatException,
    );
    await journal.file.writeAsBytes(Uint8List(20));
    await expectLater(
      PcmRecordingJournal.read(journal.file).toList(),
      throwsFormatException,
    );
  });
}
