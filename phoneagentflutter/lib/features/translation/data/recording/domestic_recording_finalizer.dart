import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import '../../domain/recording/domestic_recording_encoder.dart';
import '../../domain/recording/pcm_timeline.dart';
import 'pcm_recording_journal.dart';
import 'recording_encoding_receipt.dart';
import '../../domain/recording/domestic_recording_attachment.dart';

class FinalizedDomesticRecording {
  const FinalizedDomesticRecording(
    this.file,
    this.durationMillis,
    this.checksumSha256,
  );
  final File file;
  final int durationMillis;
  final String checksumSha256;
}

/// Disk-backed accumulator bounds memory to a chunk or a one-second window.
class DomesticRecordingFinalizer {
  const DomesticRecordingFinalizer(this.encoder);
  final DomesticRecordingEncoder encoder;

  static final _jobs =
      <String, ({int duration, Future<FinalizedDomesticRecording> work})>{};

  Future<FinalizedDomesticRecording> finalize({
    required PcmRecordingJournal journal,
    required int durationMillis,
    bool reuseEncodedDuration = false,
  }) {
    final key = journal.file.path;
    final current = _jobs[key];
    if (current != null) {
      if (!reuseEncodedDuration && current.duration != durationMillis) {
        return Future.error(
          const FormatException('Conflicting recording duration'),
        );
      }
      return current.work;
    }
    final work = _finalize(
      journal: journal,
      durationMillis: durationMillis,
      reuseEncodedDuration: reuseEncodedDuration,
    ).whenComplete(() => _jobs.remove(key));
    _jobs[key] = (duration: durationMillis, work: work);
    return work;
  }

  Future<FinalizedDomesticRecording> _finalize({
    required PcmRecordingJournal journal,
    required int durationMillis,
    required bool reuseEncodedDuration,
  }) async {
    final frames = durationMillis * 16000 ~/ 1000;
    if (durationMillis <= 0 || frames * 4 > PcmRecordingJournal.maxBytes) {
      throw const FormatException('Invalid recording duration');
    }
    await journal.finish();
    final prefix = journal.file.parent.path;
    final sumsFile = File('$prefix/mix.int32');
    final pcmFile = File('$prefix/mix.pcm16');
    final output = File('$prefix/recording.m4a');
    if (await output.exists()) {
      final size = await output.length();
      if (size <= 0 || size > PcmRecordingJournal.maxBytes) {
        throw const FormatException('Invalid encoded recording size');
      }
      final receipt = await RecordingEncodingReceipt.read(output);
      if (receipt != null) {
        if (!reuseEncodedDuration && receipt.durationMillis != durationMillis) {
          throw const FormatException('Conflicting recording duration');
        }
        return FinalizedDomesticRecording(
          output,
          receipt.durationMillis,
          receipt.checksumSha256,
        );
      }
      // A completed capture allows rebuilding an orphan left before receipt.
      await output.delete();
    }
    final stalePart = File('$prefix/recording.encoding.m4a');
    if (await stalePart.exists()) await stalePart.delete();
    try {
      await _accumulate(journal, sumsFile, frames);
      await _render(sumsFile, pcmFile, frames);
      await encoder.encode(pcmPath: pcmFile.path, m4aPath: output.path);
      final size = await output.length();
      if (size <= 0 || size > PcmRecordingJournal.maxBytes) {
        throw const FormatException('Invalid encoded recording size');
      }
      final checksum = await sha256.bind(output.openRead()).first;
      await RecordingEncodingReceipt.write(
        output,
        DomesticRecordingAttachment(
          durationMillis: durationMillis,
          checksumSha256: checksum.toString(),
        ),
      );
      return FinalizedDomesticRecording(
        output,
        durationMillis,
        checksum.toString(),
      );
    } catch (_) {
      if (await output.exists()) {
        await output.delete();
      }
      rethrow;
    } finally {
      for (final file in [sumsFile, pcmFile]) {
        if (await file.exists()) {
          await file.delete();
        }
      }
    }
  }

  Future<void> _accumulate(
    PcmRecordingJournal journal,
    File file,
    int frames,
  ) async {
    final destination = await file.open(mode: FileMode.write);
    final positioner = PcmTimelinePositioner(originNanos: journal.originNanos);
    try {
      await destination.truncate(frames * 4);
      await for (final chunk in PcmRecordingJournal.read(journal.file)) {
        final positioned = positioner.position(
          chunk.track,
          chunk.timestampNanos,
          chunk.pcm,
        );
        final start = positioned.startFrame.clamp(0, frames);
        final end = positioned.endFrame.clamp(0, frames);
        if (end <= start) {
          continue;
        }
        await destination.setPosition(start * 4);
        final bytes = await destination.read((end - start) * 4);
        if (bytes.length != (end - start) * 4) {
          throw const FormatException('Truncated mixing accumulator');
        }
        final sums = ByteData.sublistView(bytes);
        final source = ByteData.sublistView(chunk.pcm);
        for (var i = 0; i < end - start; i++) {
          final sample = source.getInt16(
            (start - positioned.startFrame + i) * 2,
            Endian.little,
          );
          sums.setInt32(
            i * 4,
            sums.getInt32(i * 4, Endian.little) + sample,
            Endian.little,
          );
        }
        await destination.setPosition(start * 4);
        await destination.writeFrom(bytes);
      }
      await destination.flush();
    } finally {
      await destination.close();
    }
  }

  Future<void> _render(File sumsFile, File pcmFile, int frames) async {
    final source = await sumsFile.open();
    final destination = await pcmFile.open(mode: FileMode.writeOnly);
    try {
      for (var offset = 0; offset < frames; offset += 16000) {
        final count = (frames - offset).clamp(0, 16000);
        final bytes = await source.read(count * 4);
        if (bytes.length != count * 4) {
          throw const FormatException('Truncated mixing accumulator');
        }
        final sums = ByteData.sublistView(bytes);
        final pcm = Uint8List(count * 2);
        final data = ByteData.sublistView(pcm);
        for (var i = 0; i < count; i++) {
          data.setInt16(
            i * 2,
            sums.getInt32(i * 4, Endian.little).clamp(-32768, 32767),
            Endian.little,
          );
        }
        await destination.writeFrom(pcm);
      }
      await destination.flush();
    } finally {
      await source.close();
      await destination.close();
    }
  }
}
