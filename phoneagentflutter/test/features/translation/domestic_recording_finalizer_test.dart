import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/translation/data/recording/domestic_recording_finalizer.dart';
import 'package:phone_agent/features/translation/data/recording/pcm_recording_journal.dart';
import 'package:phone_agent/features/translation/domain/recording/domestic_recording_encoder.dart';
import 'package:phone_agent/features/translation/domain/recording/pcm_timeline.dart';

class InspectEncoder implements DomesticRecordingEncoder {
  Uint8List? input;
  bool fail = false;
  int calls = 0;
  @override
  Future<void> encode({
    required String pcmPath,
    required String m4aPath,
  }) async {
    calls++;
    input = await File(pcmPath).readAsBytes();
    // Synthetic port result only; this test does not validate AAC encoding.
    await File(m4aPath).writeAsBytes([1, 2, 3]);
    if (fail) {
      throw const FormatException('synthetic encoder failure');
    }
  }
}

Uint8List pcm(List<int> samples) {
  final bytes = Uint8List(samples.length * 2);
  final data = ByteData.sublistView(bytes);
  for (var i = 0; i < samples.length; i++) {
    data.setInt16(i * 2, samples[i], Endian.little);
  }
  return bytes;
}

void main() {
  late Directory root;
  setUp(
    () async =>
        root = await Directory.systemTemp.createTemp('recording-finalizer'),
  );
  tearDown(() async => root.delete(recursive: true));
  Future<PcmRecordingJournal> journal() => PcmRecordingJournal.create(
    privateRoot: root,
    environment: 'test',
    apiBase: 'https://example.invalid',
    accountId: 'synthetic',
    clientCallId: 'synthetic-call',
    originNanos: 0,
  );
  test(
    'disk-backed two-track sum saturates, pads silence and cleans scratch',
    () async {
      final capture = await journal();
      capture.offer(
        RecordedPcmChunk(
          TranslationRecordingTrack.localCaller,
          0,
          pcm([30000, -30000]),
        ),
      );
      capture.offer(
        RecordedPcmChunk(
          TranslationRecordingTrack.peerFinalOutput,
          0,
          pcm([10000, -10000]),
        ),
      );
      final encoder = InspectEncoder();
      final result = await DomesticRecordingFinalizer(
        encoder,
      ).finalize(journal: capture, durationMillis: 1);
      final mixed = ByteData.sublistView(encoder.input!);
      expect(encoder.input!.length, 32);
      expect(mixed.getInt16(0, Endian.little), 32767);
      expect(mixed.getInt16(2, Endian.little), -32768);
      expect(encoder.input!.sublist(4), everyElement(0));
      expect(
        result.checksumSha256,
        '039058c6f2c0cb492c533b0a4d14ef77cc0f78abccced5287d84a1a2011cfb81',
      );
      expect(
        await File('${capture.file.parent.path}/mix.int32').exists(),
        isFalse,
      );
      expect(
        await File('${capture.file.parent.path}/mix.pcm16').exists(),
        isFalse,
      );
      expect(await capture.file.exists(), isTrue);
      final recovered = await PcmRecordingJournal.recover(capture.file);
      final again = await DomesticRecordingFinalizer(
        encoder,
      ).finalize(journal: recovered, durationMillis: 1);
      expect(again.checksumSha256, result.checksumSha256);
      expect(encoder.calls, 1);
    },
  );
  test(
    'orphan output without receipt is rebuilt only from completed capture',
    () async {
      final capture = await journal();
      capture.offer(
        RecordedPcmChunk(TranslationRecordingTrack.localCaller, 0, pcm([5])),
      );
      await capture.finish();
      await File('${capture.file.parent.path}/recording.m4a').writeAsBytes([9]);
      final encoder = InspectEncoder();
      final finalizer = DomesticRecordingFinalizer(encoder);
      final a = finalizer.finalize(journal: capture, durationMillis: 1);
      final b = finalizer.finalize(journal: capture, durationMillis: 1);
      expect(identical(a, b), true);
      await expectLater(
        finalizer.finalize(journal: capture, durationMillis: 2),
        throwsFormatException,
      );
      await a;
      expect(encoder.calls, 1);
    },
  );
  test(
    'encoder failure removes partial output but preserves recoverable journal',
    () async {
      final capture = await journal();
      capture.offer(
        RecordedPcmChunk(TranslationRecordingTrack.localCaller, 0, pcm([1])),
      );
      final encoder = InspectEncoder()..fail = true;
      await expectLater(
        DomesticRecordingFinalizer(
          encoder,
        ).finalize(journal: capture, durationMillis: 1),
        throwsFormatException,
      );
      expect(
        await File('${capture.file.parent.path}/recording.m4a').exists(),
        isFalse,
      );
      expect(await capture.file.exists(), isTrue);
      expect(await File('${capture.file.path}.complete').exists(), isTrue);
    },
  );
}
